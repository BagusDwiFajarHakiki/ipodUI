import Foundation
import UIKit
import MediaPlayer

enum IPodStreamResolutionResult {
    case playable(URL)
    case failed(reason: String)
}

private enum InnerTubeClient {
    case iosMusic
    case webRemix
    case mweb

    var clientName: String {
        switch self {
        case .iosMusic: return "IOS_MUSIC"
        case .webRemix: return "WEB_REMIX"
        case .mweb:     return "MWEB"
        }
    }

    var clientVersion: String {
        switch self {
        case .iosMusic: return "7.29.3"
        case .webRemix: return "1.20260707.12.00"
        case .mweb:     return "2.20260501.01.00"
        }
    }

    var userAgent: String {
        switch self {
        case .iosMusic:
            return "com.google.ios.youtubemusic/7.29.3 (iPhone; U; CPU iPhone OS 12_5_8 like Mac OS X; en_US)"
        case .webRemix:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        case .mweb:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1"
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

    private let songQueries = [
        "lagu indonesia populer official audio",
        "pop hits song official audio",
        "indie music song official audio",
        "acoustic song official audio",
        "electronic music song official audio"
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

    func invalidateCachedURL(for track: IPodTrack) {
        resolvedStreamURLCache.removeValue(forKey: track.id)
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

    func resolvePlayableAudio(for track: IPodTrack, forceRefresh: Bool = false, completion: @escaping (IPodStreamResolutionResult) -> Void) {
        if !forceRefresh, let cached = resolvedStreamURLCache[track.id] {
            completion(.playable(cached))
            return
        }

        guard let videoId = videoIdByTrackId[track.id], !videoId.isEmpty else {
            completion(.failed(reason: "Video ID InnerTube kosong"))
            return
        }

        let clients: [InnerTubeClient] = [.webRemix, .mweb, .iosMusic]
        resolvePlayerStream(videoId: videoId, clients: clients, index: 0, lastErrorReason: "No Direct Audio URL") { [weak self] result in
            switch result {
            case .playable(let url):
                self?.resolvedStreamURLCache[track.id] = url
                DispatchQueue.main.async { completion(.playable(url)) }

            case .failed(let playerReason):
                self?.resolveFromMobileWatchPage(videoId: videoId) { watchResult in
                    switch watchResult {
                    case .playable(let wURL):
                        self?.resolvedStreamURLCache[track.id] = wURL
                        DispatchQueue.main.async { completion(.playable(wURL)) }
                    case .failed(let watchReason):
                        DispatchQueue.main.async {
                            completion(.failed(reason: "\(playerReason) | \(watchReason)"))
                        }
                    }
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
        let q = songQueries[queryIndex % songQueries.count]
        queryIndex += 1

        let clients: [InnerTubeClient] = [.webRemix, .mweb, .iosMusic]
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
                    duration: 210,
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
        clients: [InnerTubeClient],
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
                    "hl": "id",
                    "gl": "ID"
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

        let rejectedWords = [
            "playlist", "episode", "podcast", "ep.", "ep ", "part ", "vol.", "chapter",
            "mix", "compilation", "full album", "hour", "24/7", "radio", "live", "session", "interview"
        ]

        func isPureSongTitle(_ title: String, _ artist: String) -> Bool {
            let combined = "\(title) \(artist)".lowercased()
            if rejectedWords.contains(where: { combined.contains($0) }) {
                return false
            }
            return title.count <= 75
        }

        func traverse(_ node: Any) {
            if let dict = node as? [String: Any] {
                if dict["playlistId"] != nil
                    || dict["musicPlaylistRenderer"] != nil
                    || dict["playlistRenderer"] != nil
                    || dict["playlistPanelRenderer"] != nil {
                    return
                }

                if let musicItem = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let vid = extractVideoId(from: musicItem, allowPlaylist: false), !seen.contains(vid) {
                        let texts = extractFlexColumns(from: musicItem)
                        let title = texts.first ?? ""
                        let artist = texts.dropFirst().first ?? "Unknown Artist"
                        let album = texts.dropFirst(2).first ?? "Single"
                        let thumb = extractThumbnailURL(from: musicItem)
                        if !title.isEmpty && isPureSongTitle(title, artist) {
                            seen.insert(vid)
                            list.append(InnerTubeSongEntry(videoId: vid, title: title, artist: artist, album: album, thumbnailURL: thumb))
                        }
                    }
                } else if let vid = dict["videoId"] as? String, !vid.isEmpty, !seen.contains(vid) {
                    if let titleObj = dict["title"] as? [String: Any],
                       let title = extractText(from: titleObj) {
                        let artist = extractText(from: dict["shortBylineText"] ?? dict["longBylineText"] ?? "") ?? "Unknown Artist"
                        if isPureSongTitle(title, artist) {
                            let thumb = extractThumbnailURL(from: dict)
                            seen.insert(vid)
                            list.append(InnerTubeSongEntry(videoId: vid, title: title, artist: artist, album: "Single", thumbnailURL: thumb))
                        }
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
        clients: [InnerTubeClient],
        index: Int,
        lastErrorReason: String,
        completion: @escaping (IPodStreamResolutionResult) -> Void
    ) {
        guard clients.indices.contains(index) else {
            completion(.failed(reason: lastErrorReason))
            return
        }
        let client = clients[index]
        guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            completion(.failed(reason: "Invalid Player Endpoint"))
            return
        }

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": client.clientName,
                    "clientVersion": client.clientVersion,
                    "hl": "id",
                    "gl": "ID"
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
            if let netErr = error {
                self.resolvePlayerStream(
                    videoId: videoId,
                    clients: clients,
                    index: index + 1,
                    lastErrorReason: "Net: \(netErr.localizedDescription)",
                    completion: completion
                )
                return
            }

            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data, httpCode == 200 else {
                self.resolvePlayerStream(
                    videoId: videoId,
                    clients: clients,
                    index: index + 1,
                    lastErrorReason: "HTTP \(httpCode) (\(client.clientName))",
                    completion: completion
                )
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.resolvePlayerStream(
                    videoId: videoId,
                    clients: clients,
                    index: index + 1,
                    lastErrorReason: "Invalid JSON (\(client.clientName))",
                    completion: completion
                )
                return
            }

            let extraction = self.extractAudioStreamURL(from: json)
            switch extraction {
            case .playable(let url):
                completion(.playable(url))
            case .failed(let reason):
                let statusObj = json["playabilityStatus"] as? [String: Any]
                let detail = statusObj?["reason"] as? String
                let msg = (detail?.isEmpty == false) ? detail! : reason
                self.resolvePlayerStream(
                    videoId: videoId,
                    clients: clients,
                    index: index + 1,
                    lastErrorReason: "\(client.clientName): \(msg)",
                    completion: completion
                )
            }
        }.resume()
    }

    private func extractURLFromCipher(_ cipherString: String) -> URL? {
        var extractedURL: String?
        var signatureParam: String?
        var spParam: String = "sig"

        for part in cipherString.components(separatedBy: "&") {
            let kv = part.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            let key = kv[0]
            let val = kv[1].removingPercentEncoding ?? kv[1]
            if key == "url" {
                extractedURL = val
            } else if key == "s" {
                signatureParam = val
            } else if key == "sp" && !val.isEmpty {
                spParam = val
            }
        }

        guard let baseStr = extractedURL, var comps = URLComponents(string: baseStr) else { return nil }
        if let sig = signatureParam, !sig.isEmpty {
            var items = comps.queryItems ?? []
            items.append(URLQueryItem(name: spParam, value: sig))
            comps.queryItems = items
        }
        return comps.url
    }

    private func extractAudioStreamURL(from playerJSON: [String: Any]) -> IPodStreamResolutionResult {
        guard let streamingData = playerJSON["streamingData"] as? [String: Any] else {
            return .failed(reason: "Missing streamingData")
        }
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
                return .playable(url)
            }
            if let cipher = (fmt["signatureCipher"] as? String) ?? (fmt["cipher"] as? String),
               let cipherURL = extractURLFromCipher(cipher) {
                return .playable(cipherURL)
            }
        }

        for fmt in standard {
            if let urlStr = fmt["url"] as? String, let url = URL(string: urlStr) {
                return .playable(url)
            }
            if let cipher = (fmt["signatureCipher"] as? String) ?? (fmt["cipher"] as? String),
               let cipherURL = extractURLFromCipher(cipher) {
                return .playable(cipherURL)
            }
        }

        return .failed(reason: "No Playable Audio URL")
    }

    private func resolveFromMobileWatchPage(videoId: String, completion: @escaping (IPodStreamResolutionResult) -> Void) {
        guard let url = URL(string: "https://m.youtube.com/watch?v=\(videoId)") else {
            completion(.failed(reason: "Watch URL Invalid"))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let err = error {
                completion(.failed(reason: "Watch Net: \(err.localizedDescription)"))
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data, code == 200, let html = String(data: data, encoding: .utf8) else {
                completion(.failed(reason: "Watch HTTP \(code)"))
                return
            }
            let patterns = [
                #"https?://[^"\\\s]+mime=audio[^"\\\s]+"#,
                #"https?://[^"\\\s]+googlevideo\.com/videoplayback[^"\\\s]+"#
            ]
            for pat in patterns {
                if let regex = try? NSRegularExpression(pattern: pat),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range, in: html) {
                    let decoded = String(html[range])
                        .replacingOccurrences(of: "\\u0026", with: "&")
                        .replacingOccurrences(of: "\\/", with: "/")
                    if let audioURL = URL(string: decoded) {
                        completion(.playable(audioURL))
                        return
                    }
                }
            }
            completion(.failed(reason: "Watch Audio Not Found"))
        }.resume()
    }

    private func replaceTrackArtwork(at index: Int, expectedId: String, image: UIImage) {
        guard allStreamingTracks.indices.contains(index),
              allStreamingTracks[index].id == expectedId else { return }
        let old = allStreamingTracks[index]
        allStreamingTracks[index] = makeTrack(
            id: old.id,
            title: old.title,
            artist: old.artist,
            album: old.album,
            duration: old.duration,
            assetURL: old.assetURL,
            artworkImage: image
        )
    }

    private func loadLowResThumbnailsAsync(for tracks: [IPodTrack]) {
        for (idx, track) in tracks.enumerated() {
            guard let thumbStr = thumbnailURLByTrackId[track.id],
                  let url = URL(string: thumbStr) else { continue }
            if let cached = artworkCache[thumbStr] {
                replaceTrackArtwork(at: idx, expectedId: track.id, image: cached)
                continue
            }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let rawImg = UIImage(data: data) else { return }
                let lowRes = self.downsampleImage(rawImg, targetSide: 96)
                self.artworkCache[thumbStr] = lowRes
                DispatchQueue.main.async {
                    self.replaceTrackArtwork(at: idx, expectedId: track.id, image: lowRes)
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