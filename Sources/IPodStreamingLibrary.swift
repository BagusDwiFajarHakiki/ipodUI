import Foundation
import UIKit
import MediaPlayer

private enum MetroLiteStreamClient {
    case iosMusic
    case webRemix
    case tvEmbedded

    var clientName: String {
        switch self {
        case .iosMusic:   return "IOS_MUSIC"
        case .webRemix:   return "WEB_REMIX"
        case .tvEmbedded: return "TVHTML5_SIMPLY_EMBEDDED_PLAYER"
        }
    }

    var clientVersion: String {
        switch self {
        case .iosMusic:   return "6.42.1"
        case .webRemix:   return "1.20250101.01.00"
        case .tvEmbedded: return "2.0"
        }
    }

    var userAgent: String {
        switch self {
        case .iosMusic:
            return "com.google.ios.youtubemusic/6.42.1 (iPhone; U; CPU iPhone OS 12_5_8 like Mac OS X; en_US)"
        case .webRemix:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        case .tvEmbedded:
            return "Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) TV Safari/537.36"
        }
    }
}

final class IPodStreamingLibrary {
    static let shared = IPodStreamingLibrary()
    static let pageSize: Int = 50

    private(set) var allStreamingTracks: [IPodTrack] = []
    private var videoIdByTrackId: [String: String] = [:]
    private var resolvedAudioURLCache: [String: URL] = [:]
    private var artworkCache: [String: UIImage] = [:]
    private let searchQueries = [
        "lofi hip hop radio beats",
        "indie acoustic chill music",
        "city pop synthwave instrumental",
        "jazz piano ambient study"
    ]
    private var queryCursor: Int = 0

    private init() {
        loadSeedFallbackTracks()
        fetchOnlineTracksFromInnerTube(reshuffle: false) { _ in }
    }

    private func makeTrack(
        id: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        assetURL: URL?,
        artworkImage: UIImage?
    ) -> IPodTrack {
        return IPodTrack(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            assetURL: assetURL,
            mediaItem: nil,
            artworkImage: artworkImage
        )
    }

    func refreshTracks(completion: @escaping (Bool) -> Void) {
        fetchOnlineTracksFromInnerTube(reshuffle: true) { [weak self] success in
            if !success {
                self?.loadSeedFallbackTracks(reshuffle: true)
            }
            completion(true)
        }
    }

    func tracksPage(pageIndex: Int) -> (tracks: [IPodTrack], currentPage: Int, totalPages: Int, hasNextPage: Bool) {
        let total = allStreamingTracks.count
        guard total > 0 else {
            return ([], 0, 1, false)
        }
        let totalPages = max(1, Int(ceil(Double(total) / Double(Self.pageSize))))
        let safePage = min(max(0, pageIndex), totalPages - 1)
        let start = safePage * Self.pageSize
        let end = min(start + Self.pageSize, total)
        let slice = Array(allStreamingTracks[start..<end])
        return (slice, safePage, totalPages, safePage + 1 < totalPages)
    }

    func buildRelatedQueue(startingWith selectedTrack: IPodTrack, in pool: [IPodTrack]) -> [IPodTrack] {
        let source = pool.isEmpty ? allStreamingTracks : pool
        guard !source.isEmpty else { return [selectedTrack] }

        let others = source.filter { $0.id != selectedTrack.id }
        let selectedWords = Set(
            (selectedTrack.title + " " + selectedTrack.artist + " " + selectedTrack.album)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
        )

        let scored = others.map { candidate -> (track: IPodTrack, score: Int, jitter: Int) in
            var score = 0
            if candidate.artist.caseInsensitiveCompare(selectedTrack.artist) == .orderedSame {
                score += 10
            }
            if candidate.album.caseInsensitiveCompare(selectedTrack.album) == .orderedSame {
                score += 6
            }
            let candWords = Set(
                (candidate.title + " " + candidate.artist + " " + candidate.album)
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count >= 3 }
            )
            let overlapCount = selectedWords.intersection(candWords).count
            score += overlapCount * 3
            return (candidate, score, Int.random(in: 0...4))
        }

        let sortedRelated = scored.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.jitter < $1.jitter
        }.map { $0.track }

        return [selectedTrack] + sortedRelated
    }

    // Mengambil URL audio stream asli (audio/mp4) dengan rotasi klien MetroLite + fallback watch page
    func resolvePlayableAudioURL(for track: IPodTrack, completion: @escaping (URL?) -> Void) {
        if let cached = resolvedAudioURLCache[track.id] {
            completion(cached)
            return
        }

        if let existing = track.assetURL, existing.scheme == "https" || existing.scheme == "http" {
            if !existing.absoluteString.contains("youtube.com/watch") {
                resolvedAudioURLCache[track.id] = existing
                completion(existing)
                return
            }
        }

        guard let videoId = videoIdByTrackId[track.id], !videoId.isEmpty else {
            completion(track.assetURL)
            return
        }

        let clients: [MetroLiteStreamClient] = [.iosMusic, .webRemix, .tvEmbedded]
        resolveStreamViaClients(videoId: videoId, clients: clients, index: 0) { [weak self] resolvedURL in
            if let url = resolvedURL {
                self?.resolvedAudioURLCache[track.id] = url
                DispatchQueue.main.async { completion(url) }
                return
            }
            // Fallback ekstraksi dari halaman watch mobile jika semua player client terkena blokir/403
            self?.resolveStreamFromMobileWatchPage(videoId: videoId) { watchURL in
                if let wURL = watchURL {
                    self?.resolvedAudioURLCache[track.id] = wURL
                }
                DispatchQueue.main.async {
                    completion(watchURL ?? track.assetURL)
                }
            }
        }
    }

    private func fetchOnlineTracksFromInnerTube(reshuffle: Bool, completion: @escaping (Bool) -> Void) {
        let query = searchQueries[queryCursor % searchQueries.count]
        queryCursor += 1

        let searchClients: [MetroLiteStreamClient] = [.webRemix, .iosMusic]
        searchInnerTube(query: query, clients: searchClients, index: 0) { [weak self] items in
            guard let self = self, !items.isEmpty else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            // Gandakan hasil agar katalog streaming siap di-paging 50 item per halaman dengan cepat
            var collected: [IPodTrack] = []
            var idMap: [String: String] = [:]

            for repeatPass in 0..<2 {
                for (idx, item) in items.enumerated() {
                    let trackId = "yt_\(repeatPass)_\(item.videoId)_\(idx)"
                    let title = repeatPass == 0 ? item.title : "\(item.title) (Mix)"
                    let art = self.makeLowResArtwork(title: title, artist: item.artist, tag: "Stream")
                    let watchPlaceholder = URL(string: "https://m.youtube.com/watch?v=\(item.videoId)")
                    let track = self.makeTrack(
                        id: trackId,
                        title: title,
                        artist: item.artist,
                        album: item.album,
                        duration: item.duration,
                        assetURL: watchPlaceholder,
                        artworkImage: art
                    )
                    collected.append(track)
                    idMap[trackId] = item.videoId
                }
            }

            DispatchQueue.main.async {
                self.videoIdByTrackId = idMap
                self.allStreamingTracks = reshuffle ? collected.shuffled() : collected
                completion(true)
            }
        }
    }

    private struct ParsedSearchTrack {
        let videoId: String
        let title: String
        let artist: String
        let album: String
        let duration: TimeInterval
    }

    private func searchInnerTube(
        query: String,
        clients: [MetroLiteStreamClient],
        index: Int,
        completion: @escaping ([ParsedSearchTrack]) -> Void
    ) {
        guard clients.indices.contains(index) else {
            completion([])
            return
        }
        let client = clients[index]
        guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/search?prettyPrint=false") else {
            completion([])
            return
        }

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": client.clientName,
                    "clientVersion": client.clientVersion,
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "query": query
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 8.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self?.searchInnerTube(query: query, clients: clients, index: index + 1, completion: completion)
                return
            }

            let parsed = self.extractTracksFromSearchJSON(json)
            if !parsed.isEmpty {
                completion(parsed)
            } else {
                self.searchInnerTube(query: query, clients: clients, index: index + 1, completion: completion)
            }
        }.resume()
    }

    private func extractTracksFromSearchJSON(_ root: Any) -> [ParsedSearchTrack] {
        var results: [ParsedSearchTrack] = []
        var seenIds = Set<String>()

        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if let renderer = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let vid = extractVideoId(from: renderer), !seenIds.contains(vid) {
                        seenIds.insert(vid)
                        let texts = extractFlexStrings(from: renderer)
                        let title = texts.first ?? "Streaming Track"
                        let artist = texts.dropFirst().first ?? "MetroLite Stream"
                        let album = texts.dropFirst(2).first ?? "YouTube Music"
                        results.append(ParsedSearchTrack(videoId: vid, title: title, artist: artist, album: album, duration: 195))
                    }
                } else if let vid = dict["videoId"] as? String, !vid.isEmpty, !seenIds.contains(vid) {
                    if let titleObj = dict["title"] as? [String: Any],
                       let titleText = extractText(from: titleObj) {
                        seenIds.insert(vid)
                        let authorText = extractText(from: dict["shortBylineText"] ?? dict["longBylineText"] ?? "") ?? "Online Audio"
                        results.append(ParsedSearchTrack(videoId: vid, title: titleText, artist: authorText, album: "Online Stream", duration: 195))
                    }
                }
                for val in dict.values {
                    walk(val)
                }
            } else if let arr = node as? [Any] {
                for item in arr {
                    walk(item)
                }
            }
        }

        walk(root)
        return results
    }

    private func extractVideoId(from renderer: [String: Any]) -> String? {
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let watch = nav["watchEndpoint"] as? [String: Any],
           let vid = watch["videoId"] as? String {
            return vid
        }
        if let overlay = renderer["overlay"] as? [String: Any],
           let button = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
           let content = button["content"] as? [String: Any],
           let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
           let ep = playBtn["playNavigationEndpoint"] as? [String: Any],
           let watch = ep["watchEndpoint"] as? [String: Any],
           let vid = watch["videoId"] as? String {
            return vid
        }
        return nil
    }

    private func extractFlexStrings(from renderer: [String: Any]) -> [String] {
        var collected: [String] = []
        if let cols = renderer["flexColumns"] as? [[String: Any]] {
            for col in cols {
                if let colRenderer = col["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                   let textObj = colRenderer["text"],
                   let str = extractText(from: textObj),
                   !str.isEmpty {
                    collected.append(str)
                }
            }
        }
        return collected
    }

    private func extractText(from anyObj: Any) -> String? {
        if let dict = anyObj as? [String: Any] {
            if let simple = dict["simpleText"] as? String {
                return simple
            }
            if let runs = dict["runs"] as? [[String: Any]] {
                let joined = runs.compactMap { $0["text"] as? String }.joined()
                if !joined.isEmpty { return joined }
            }
        }
        return nil
    }

    private func resolveStreamViaClients(
        videoId: String,
        clients: [MetroLiteStreamClient],
        index: Int,
        completion: @escaping (URL?) -> Void
    ) {
        guard clients.indices.contains(index) else {
            completion(nil)
            return
        }
        let client = clients[index]
        guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            completion(nil)
            return
        }

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": client.clientName,
                    "clientVersion": client.clientVersion,
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 8.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self?.resolveStreamViaClients(videoId: videoId, clients: clients, index: index + 1, completion: completion)
                return
            }

            // Cek jika terkena LOGIN_REQUIRED atau status error
            if let playability = json["playabilityStatus"] as? [String: Any],
               let status = playability["status"] as? String,
               status.uppercased().contains("LOGIN_REQUIRED") {
                self.resolveStreamViaClients(videoId: videoId, clients: clients, index: index + 1, completion: completion)
                return
            }

            if let audioURL = self.extractAudioMP4URL(from: json) {
                completion(audioURL)
            } else {
                self.resolveStreamViaClients(videoId: videoId, clients: clients, index: index + 1, completion: completion)
            }
        }.resume()
    }

    private func extractAudioMP4URL(from playerJSON: [String: Any]) -> URL? {
        guard let streamingData = playerJSON["streamingData"] as? [String: Any] else { return nil }
        let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] ?? []
        let formats = streamingData["formats"] as? [[String: Any]] ?? []

        let audioCandidates = adaptiveFormats.filter { fmt in
            let mime = (fmt["mimeType"] as? String ?? "").lowercased()
            return mime.contains("audio/mp4") || mime.contains("audio/")
        }

        let sortedAudio = audioCandidates.sorted {
            let b1 = $0["bitrate"] as? Int ?? 0
            let b2 = $1["bitrate"] as? Int ?? 0
            return b1 > b2
        }

        for fmt in sortedAudio {
            if let urlStr = fmt["url"] as? String, let url = URL(string: urlStr) {
                return url
            }
        }

        for fmt in formats {
            if let urlStr = fmt["url"] as? String, let url = URL(string: urlStr) {
                return url
            }
        }

        return nil
    }

    private func resolveStreamFromMobileWatchPage(videoId: String, completion: @escaping (URL?) -> Void) {
        guard let watchURL = URL(string: "https://m.youtube.com/watch?v=\(videoId)") else {
            completion(nil)
            return
        }
        var req = URLRequest(url: watchURL)
        req.timeoutInterval = 8.0
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            // Ekstrak URL audio/mp4 langsung dari payload player jika tersedia di halaman watch
            let pattern = #"https?://[^"\\\s]+mime=audio[^"\\\s]+"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range, in: html) {
                let raw = String(html[range])
                    .replacingOccurrences(of: "\\u0026", with: "&")
                    .replacingOccurrences(of: "\\/", with: "/")
                completion(URL(string: raw))
                return
            }
            completion(nil)
        }.resume()
    }

    private func loadSeedFallbackTracks(reshuffle: Bool = false) {
        let items: [(id: String, title: String, artist: String, album: String, duration: TimeInterval, url: String)] = [
            ("fb_1", "Sunset Mirage", "Kaito", "Night Signals", 214, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"),
            ("fb_2", "Midnight Transit", "Sora", "City Lights", 198, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"),
            ("fb_3", "Glass Horizon", "Mina", "Quiet Hours", 226, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3"),
            ("fb_4", "Velvet Static", "Renji", "Orbit", 184, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3"),
            ("fb_5", "Harbor Breeze", "Hana", "Coastal Wind", 205, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3")
        ]
        var list: [IPodTrack] = []
        for idx in 0..<60 {
            let b = items[idx % items.count]
            let art = makeLowResArtwork(title: b.title, artist: b.artist, tag: "Online")
            list.append(makeTrack(
                id: "\(b.id)_\(idx)",
                title: b.title,
                artist: b.artist,
                album: b.album,
                duration: b.duration,
                assetURL: URL(string: b.url),
                artworkImage: art
            ))
        }
        allStreamingTracks = reshuffle ? list.shuffled() : list
    }

    // Resolusi rendah (96x96) agar cepat di-load dan ringan di iPhone 5s
    private func makeLowResArtwork(title: String, artist: String, tag: String) -> UIImage? {
        let key = "\(artist)_\(tag)"
        if let cached = artworkCache[key] {
            return cached
        }

        let hash = abs(key.hashValue)
        let hue = CGFloat(hash % 360) / 360.0
        let bgColor = UIColor(hue: hue, saturation: 0.56, brightness: 0.34, alpha: 1.0)
        let accentColor = UIColor(hue: fmod(hue + 0.16, 1.0), saturation: 0.70, brightness: 0.76, alpha: 1.0)

        let size = CGSize(width: 96, height: 96)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        bgColor.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        accentColor.withAlphaComponent(0.30).setFill()
        UIBezierPath(ovalIn: CGRect(x: -10, y: -10, width: 68, height: 68)).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let glyph = "♪"
        let gSize = glyph.size(withAttributes: attrs)
        glyph.draw(
            at: CGPoint(x: (size.width - gSize.width) / 2.0, y: (size.height - gSize.height) / 2.0 - 5),
            withAttributes: attrs
        )

        let tagAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.88)
        ]
        let label = tag.uppercased()
        let lSize = label.size(withAttributes: tagAttrs)
        label.draw(
            at: CGPoint(x: (size.width - lSize.width) / 2.0, y: size.height - lSize.height - 7),
            withAttributes: tagAttrs
        )

        let img = UIGraphicsGetImageFromCurrentImageContext()
        if let img = img {
            artworkCache[key] = img
        }
        return img
    }
}