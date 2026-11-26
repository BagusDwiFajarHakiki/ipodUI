import Foundation
import UIKit
import MediaPlayer

private enum MetroLite12Client {
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
    private var thumbnailURLByTrackId: [String: String] = [:]
    private var resolvedStreamURLCache: [String: URL] = [:]
    private var artworkCache: [String: UIImage] = [:]

    private let queries = [
        "pop hits official audio",
        "indie acoustic song",
        "synthwave electronic music",
        "lo fi beats chill song",
        "rock alternative track"
    ]
    private var queryIndex: Int = 0

    private init() {
        fetchSongsFromInnerTube(reshuffle: false) { _ in }
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
        fetchSongsFromInnerTube(reshuffle: true, completion: completion)
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
        let selectedTokens = Set(
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
            let candTokens = Set(
                (candidate.title + " " + candidate.artist + " " + candidate.album)
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count >= 3 }
            )
            let overlap = selectedTokens.intersection(candTokens).count
            score += overlap * 3
            return (candidate, score, Int.random(in: 0...4))
        }

        let ordered = scored.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.jitter < $1.jitter
        }.map { $0.track }

        return [selectedTrack] + ordered
    }

    func resolvePlayableAudioURL(for track: IPodTrack, completion: @escaping (URL?) -> Void) {
        if let cached = resolvedStreamURLCache[track.id] {
            completion(cached)
            return
        }

        guard let videoId = videoIdByTrackId[track.id], !videoId.isEmpty else {
            completion(track.assetURL)
            return
        }

        let clients: [MetroLite12Client] = [.iosMusic, .webRemix, .tvEmbedded]
        resolvePlayerStream(videoId: videoId, clients: clients, index: 0) { [weak self] streamURL in
            if let url = streamURL {
                self?.resolvedStreamURLCache[track.id] = url
                DispatchQueue.main.async { completion(url) }
                return
            }

            // Fallback ekstraksi dari halaman watch mobile jika terkena blokir / LOGIN_REQUIRED / 403
            self?.resolveFromMobileWatchPage(videoId: videoId) { watchStreamURL in
                if let wURL = watchStreamURL {
                    self?.resolvedStreamURLCache[track.id] = wURL
                }
                DispatchQueue.main.async {
                    completion(watchStreamURL)
                }
            }
        }
    }

    private struct InnerTubeSongEntry {
        let videoId: String
        let title: String
        let artist: String
        let album: String
        let thumbnailURL: String?
    }

    private func fetchSongsFromInnerTube(reshuffle: Bool, completion: @escaping (Bool) -> Void) {
        let q = queries[queryIndex % queries.count]
        queryIndex += 1

        let clients: [MetroLite12Client] = [.iosMusic, .webRemix, .tvEmbedded]
        searchInnerTube(query: q, clients: clients, index: 0) { [weak self] entries in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            var tracks: [IPodTrack] = []
            var idMap: [String: String] = [:]
            var thumbMap: [String: String] = [:]

            for (idx, entry) in entries.enumerated() {
                let trackId = "innertube_\(entry.videoId)_\(idx)"
                let placeholderArt = self.placeholderArtwork(seed: entry.videoId)
                let watchURL = URL(string: "https://m.youtube.com/watch?v=\(entry.videoId)")
                let track = self.makeTrack(
                    id: trackId,
                    title: entry.title,
                    artist: entry.artist,
                    album: entry.album,
                    duration: 195,
                    assetURL: watchURL,
                    artworkImage: placeholderArt
                )
                tracks.append(track)
                idMap[trackId] = entry.videoId
                if let tURL = entry.thumbnailURL {
                    thumbMap[trackId] = tURL
                }
            }

            DispatchQueue.main.async {
                self.videoIdByTrackId = idMap
                self.thumbnailURLByTrackId = thumbMap
                self.allStreamingTracks = reshuffle ? tracks.shuffled() : tracks
                self.loadLowResThumbnailsAsync(for: self.allStreamingTracks)
                completion(!tracks.isEmpty)
            }
        }
    }

    private func searchInnerTube(
        query: String,
        clients: [MetroLite12Client],
        index: Int,
        completion: @escaping ([InnerTubeSongEntry]) -> Void
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

        let body: [String: Any] = [
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
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let data = data,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.searchInnerTube(query: query, clients: clients, index: index + 1, completion: completion)
                return
            }

            let parsed = self.parseSongsFromSearchJSON(json)
            if !parsed.isEmpty {
                completion(parsed)
            } else {
                self.searchInnerTube(query: query, clients: clients, index: index + 1, completion: completion)
            }
        }.resume()
    }

    private func parseSongsFromSearchJSON(_ root: Any) -> [InnerTubeSongEntry] {
        var list: [InnerTubeSongEntry] = []
        var seen = Set<String>()

        let excludedWords = ["playlist", "mix", "compilation", "full album", "hour", "24/7", "radio"]

        func isAllowedSongTitle(_ title: String) -> Bool {
            let lower = title.lowercased()
            return !excludedWords.contains { lower.contains($0) }
        }

        func traverse(_ node: Any) {
            if let dict = node as? [String: Any] {
                if dict["playlistId"] != nil || dict["musicPlaylistRenderer"] != nil || dict["playlistRenderer"] != nil {
                    return
                }

                if let musicItem = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let vid = extractVideoId(from: musicItem, allowPlaylist: false), !seen.contains(vid) {
                        let texts = extractFlexColumns(from: musicItem)
                        let title = texts.first ?? ""
                        let artist = texts.dropFirst().first ?? "Unknown Artist"
                        let album = texts.dropFirst(2).first ?? "Single"
                        let thumb = extractThumbnailURL(from: musicItem)
                        if !title.isEmpty && isAllowedSongTitle(title) {
                            seen.insert(vid)
                            list.append(InnerTubeSongEntry(videoId: vid, title: title, artist: artist, album: album, thumbnailURL: thumb))
                        }
                    }
                } else if let vid = dict["videoId"] as? String, !vid.isEmpty, !seen.contains(vid) {
                    if let titleObj = dict["title"] as? [String: Any],
                       let title = extractText(from: titleObj),
                       isAllowedSongTitle(title) {
                        let artist = extractText(from: dict["shortBylineText"] ?? dict["longBylineText"] ?? "") ?? "Unknown Artist"
                        let thumb = extractThumbnailURL(from: dict)
                        seen.insert(vid)
                        list.append(InnerTubeSongEntry(videoId: vid, title: title, artist: artist, album: "Single", thumbnailURL: thumb))
                    }
                }

                for value in dict.values {
                    traverse(value)
                }
            } else if let array = node as? [Any] {
                for item in array {
                    traverse(item)
                }
            }
        }

        traverse(root)
        return list
    }

    private func extractVideoId(from renderer: [String: Any], allowPlaylist: Bool) -> String? {
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let watch = nav["watchEndpoint"] as? [String: Any],
           (allowPlaylist || watch["playlistId"] == nil),
           let vid = watch["videoId"] as? String {
            return vid
        }
        if let overlay = renderer["overlay"] as? [String: Any],
           let thumbOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
           let content = thumbOverlay["content"] as? [String: Any],
           let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
           let ep = playBtn["playNavigationEndpoint"] as? [String: Any],
           let watch = ep["watchEndpoint"] as? [String: Any],
           (allowPlaylist || watch["playlistId"] == nil),
           let vid = watch["videoId"] as? String {
            return vid
        }
        return nil
    }

    private func extractFlexColumns(from renderer: [String: Any]) -> [String] {
        var result: [String] = []
        if let cols = renderer["flexColumns"] as? [[String: Any]] {
            for col in cols {
                if let flex = col["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                   let textObj = flex["text"],
                   let str = extractText(from: textObj),
                   !str.isEmpty {
                    result.append(str)
                }
            }
        }
        return result
    }

    private func extractThumbnailURL(from dict: [String: Any]) -> String? {
        if let thumbObj = dict["thumbnail"] as? [String: Any],
           let musicThumb = thumbObj["musicThumbnailRenderer"] as? [String: Any],
           let innerThumb = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = innerThumb["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            return urlStr
        }
        if let thumbObj = dict["thumbnail"] as? [String: Any],
           let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            return urlStr
        }
        return nil
    }

    private func extractText(from anyValue: Any) -> String? {
        if let dict = anyValue as? [String: Any] {
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

    private func resolvePlayerStream(
        videoId: String,
        clients: [MetroLite12Client],
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
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let data = data,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.resolvePlayerStream(videoId: videoId, clients: clients, index: index + 1, completion: completion)
                return
            }

            if let statusObj = json["playabilityStatus"] as? [String: Any],
               let status = statusObj["status"] as? String {
                let upper = status.uppercased()
                if upper.contains("LOGIN_REQUIRED") || upper.contains("ERROR") || upper.contains("UNPLAYABLE") {
                    self.resolvePlayerStream(videoId: videoId, clients: clients, index: index + 1, completion: completion)
                    return
                }
            }

            if let streamURL = self.extractAudioStreamURL(from: json) {
                completion(streamURL)
            } else {
                self.resolvePlayerStream(videoId: videoId, clients: clients, index: index + 1, completion: completion)
            }
        }.resume()
    }

    private func extractAudioStreamURL(from playerJSON: [String: Any]) -> URL? {
        guard let streamingData = playerJSON["streamingData"] as? [String: Any] else { return nil }
        let adaptive = streamingData["adaptiveFormats"] as? [[String: Any]] ?? []
        let standard = streamingData["formats"] as? [[String: Any]] ?? []

        let audioFormats = adaptive.filter { fmt in
            let mime = (fmt["mimeType"] as? String ?? "").lowercased()
            return mime.contains("audio/mp4") || mime.contains("audio/")
        }

        let sortedAudio = audioFormats.sorted {
            let b1 = $0["bitrate"] as? Int ?? 0
            let b2 = $1["bitrate"] as? Int ?? 0
            return b1 > b2
        }

        for fmt in sortedAudio {
            if let urlStr = fmt["url"] as? String, let url = URL(string: urlStr) {
                return url
            }
        }

        for fmt in standard {
            if let urlStr = fmt["url"] as? String, let url = URL(string: urlStr) {
                return url
            }
        }

        return nil
    }

    private func resolveFromMobileWatchPage(videoId: String, completion: @escaping (URL?) -> Void) {
        guard let url = URL(string: "https://m.youtube.com/watch?v=\(videoId)") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            let pattern = #"https?://[^"\\\s]+mime=audio[^"\\\s]+"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range, in: html) {
                let decoded = String(html[range])
                    .replacingOccurrences(of: "\\u0026", with: "&")
                    .replacingOccurrences(of: "\\/", with: "/")
                completion(URL(string: decoded))
                return
            }
            completion(nil)
        }.resume()
    }

    private func loadLowResThumbnailsAsync(for tracks: [IPodTrack]) {
        for (idx, track) in tracks.enumerated() {
            guard let thumbStr = thumbnailURLByTrackId[track.id],
                  let url = URL(string: thumbStr) else { continue }
            if let cached = artworkCache[thumbStr] {
                allStreamingTracks[idx].artworkImage = cached
                continue
            }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let rawImg = UIImage(data: data) else { return }
                let lowRes = self.downsampleImage(rawImg, targetSide: 96)
                self.artworkCache[thumbStr] = lowRes
                DispatchQueue.main.async {
                    if self.allStreamingTracks.indices.contains(idx),
                       self.allStreamingTracks[idx].id == track.id {
                        self.allStreamingTracks[idx].artworkImage = lowRes
                    }
                }
            }.resume()
        }
    }

    private func downsampleImage(_ image: UIImage, targetSide: CGFloat) -> UIImage {
        let size = CGSize(width: targetSide, height: targetSide)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    private func placeholderArtwork(seed: String) -> UIImage? {
        if let cached = artworkCache[seed] {
            return cached
        }
        let hue = CGFloat(abs(seed.hashValue) % 360) / 360.0
        let size = CGSize(width: 96, height: 96)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        UIColor(hue: hue, saturation: 0.50, brightness: 0.28, alpha: 1.0).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 30, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let note = "♪"
        let nSize = note.size(withAttributes: attrs)
        note.draw(
            at: CGPoint(x: (size.width - nSize.width) / 2.0, y: (size.height - nSize.height) / 2.0),
            withAttributes: attrs
        )

        let img = UIGraphicsGetImageFromCurrentImageContext()
        if let img = img {
            artworkCache[seed] = img
        }
        return img
    }
}