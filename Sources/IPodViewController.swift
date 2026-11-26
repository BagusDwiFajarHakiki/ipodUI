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

    private let songQueries = [
        "official audio song",
        "indie song acoustic",
        "synthwave song track",
        "city pop song",
        "jazz instrumental song"
    ]
    private var queryCursor: Int = 0

    private let verifiedAudioStreams: [String] = [
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3"
    ]

    private init() {
        loadSongsCatalog(reshuffle: false)
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
        fetchSongsFromInnerTube(reshuffle: true) { [weak self] success in
            if !success {
                self?.loadSongsCatalog(reshuffle: true)
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

    func resolvePlayableAudioURL(for track: IPodTrack, completion: @escaping (URL?) -> Void) {
        if let cached = resolvedAudioURLCache[track.id] {
            completion(cached)
            return
        }

        let fallbackStreamURL = track.assetURL ?? URL(string: verifiedAudioStreams[abs(track.id.hashValue) % verifiedAudioStreams.count])

        guard let videoId = videoIdByTrackId[track.id], !videoId.isEmpty else {
            if let fURL = fallbackStreamURL {
                resolvedAudioURLCache[track.id] = fURL
            }
            completion(fallbackStreamURL)
            return
        }

        let clients: [MetroLiteStreamClient] = [.iosMusic, .webRemix, .tvEmbedded]
        resolveStreamViaClients(videoId: videoId, clients: clients, index: 0) { [weak self] resolvedURL in
            guard let self = self else {
                completion(fallbackStreamURL)
                return
            }
            if let url = resolvedURL {
                self.resolvedAudioURLCache[track.id] = url
                DispatchQueue.main.async { completion(url) }
                return
            }

            if let fURL = fallbackStreamURL {
                self.resolvedAudioURLCache[track.id] = fURL
            }
            DispatchQueue.main.async {
                completion(fallbackStreamURL)
            }
        }
    }

    private func fetchSongsFromInnerTube(reshuffle: Bool, completion: @escaping (Bool) -> Void) {
        let query = songQueries[queryCursor % songQueries.count]
        queryCursor += 1

        let searchClients: [MetroLiteStreamClient] = [.webRemix, .iosMusic]
        searchInnerTubeSongsOnly(query: query, clients: searchClients, index: 0) { [weak self] items in
            guard let self = self, !items.isEmpty else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            var collected: [IPodTrack] = []
            var idMap: [String: String] = [:]

            for (idx, item) in items.prefix(100).enumerated() {
                let trackId = "song_online_\(idx)_\(item.videoId)"
                let art = self.makeLowResArtwork(title: item.title, artist: item.artist, tag: "Song")
                let streamURL = URL(string: self.verifiedAudioStreams[idx % self.verifiedAudioStreams.count])
                let track = self.makeTrack(
                    id: trackId,
                    title: item.title,
                    artist: item.artist,
                    album: item.album,
                    duration: item.duration,
                    assetURL: streamURL,
                    artworkImage: art
                )
                collected.append(track)
                idMap[trackId] = item.videoId
            }

            DispatchQueue.main.async {
                self.videoIdByTrackId = idMap
                self.allStreamingTracks = reshuffle ? collected.shuffled() : collected
                completion(!collected.isEmpty)
            }
        }
    }

    private struct ParsedSongItem {
        let videoId: String
        let title: String
        let artist: String
        let album: String
        let duration: TimeInterval
    }

    private func searchInnerTubeSongsOnly(
        query: String,
        clients: [MetroLiteStreamClient],
        index: Int,
        completion: @escaping ([ParsedSongItem]) -> Void
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
            guard let self = self else { return }
            guard let data = data,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.searchInnerTubeSongsOnly(query: query, clients: clients, index: index + 1, completion: completion)
                return
            }

            let songs = self.extractOnlySongsFromSearchJSON(json)
            if !songs.isEmpty {
                completion(songs)
            } else {
                self.searchInnerTubeSongsOnly(query: query, clients: clients, index: index + 1, completion: completion)
            }
        }.resume()
    }

    private func extractOnlySongsFromSearchJSON(_ root: Any) -> [ParsedSongItem] {
        var results: [ParsedSongItem] = []
        var seenIds = Set<String>()

        let bannedKeywords = ["playlist", "mix", "compilation", "full album", "hour", "24/7", "radio", "live set"]

        func isSongTitleAllowed(_ title: String) -> Bool {
            let lower = title.lowercased()
            return !bannedKeywords.contains { lower.contains($0) }
        }

        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if dict["playlistId"] != nil || dict["musicPlaylistRenderer"] != nil || dict["playlistRenderer"] != nil {
                    return
                }

                if let renderer = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let vid = extractSongVideoId(from: renderer), !seenIds.contains(vid) {
                        let texts = extractFlexStrings(from: renderer)
                        let title = texts.first ?? ""
                        let artist = texts.dropFirst().first ?? "Unknown Artist"
                        let album = texts.dropFirst(2).first ?? "Single"
                        if !title.isEmpty && isSongTitleAllowed(title) {
                            seenIds.insert(vid)
                            results.append(ParsedSongItem(videoId: vid, title: title, artist: artist, album: album, duration: 205))
                        }
                    }
                } else if let vid = dict["videoId"] as? String, !vid.isEmpty, !seenIds.contains(vid) {
                    if let titleObj = dict["title"] as? [String: Any],
                       let titleText = extractText(from: titleObj),
                       isSongTitleAllowed(titleText) {
                        let authorText = extractText(from: dict["shortBylineText"] ?? dict["longBylineText"] ?? "") ?? "Unknown Artist"
                        seenIds.insert(vid)
                        results.append(ParsedSongItem(videoId: vid, title: titleText, artist: authorText, album: "Single", duration: 205))
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

    private func extractSongVideoId(from renderer: [String: Any]) -> String? {
        if let nav = renderer["navigationEndpoint"] as? [String: Any],
           let watch = nav["watchEndpoint"] as? [String: Any],
           watch["playlistId"] == nil,
           let vid = watch["videoId"] as? String {
            return vid
        }
        if let overlay = renderer["overlay"] as? [String: Any],
           let button = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
           let content = button["content"] as? [String: Any],
           let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
           let ep = playBtn["playNavigationEndpoint"] as? [String: Any],
           let watch = ep["watchEndpoint"] as? [String: Any],
           watch["playlistId"] == nil,
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
            guard let self = self else { return }
            guard let data = data,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.resolveStreamViaClients(videoId: videoId, clients: clients, index: index + 1, completion: completion)
                return
            }

            if let playability = json["playabilityStatus"] as? [String: Any],
               let status = playability["status"] as? String,
               status.uppercased().contains("LOGIN_REQUIRED") {
                self.resolveStreamViaClients(videoId: videoId, clients: clients, index: index + 1, completion: completion)
                return
            }

            if let audioURL = self.extractDirectAudioURL(from: json) {
                completion(audioURL)
            } else {
                self.resolveStreamViaClients(videoId: videoId, clients: clients, index: index + 1, completion: completion)
            }
        }.resume()
    }

    private func extractDirectAudioURL(from playerJSON: [String: Any]) -> URL? {
        guard let streamingData = playerJSON["streamingData"] as? [String: Any] else { return nil }
        let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] ?? []
        let formats = streamingData["formats"] as? [[String: Any]] ?? []

        let audioCandidates = adaptiveFormats.filter { fmt in
            let mime = (fmt["mimeType"] as? String ?? "").lowercased()
            return (mime.contains("audio/mp4") || mime.contains("audio/mpeg")) && fmt["url"] != nil
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

    private func loadSongsCatalog(reshuffle: Bool = false) {
        let songs: [(title: String, artist: String, album: String, duration: TimeInterval)] = [
            ("Hati-Hati di Jalan", "Tulus", "Manusia", 262),
            ("Monokrom", "Tulus", "Monokrom", 213),
            ("Bertaut", "Nadin Amizah", "Selamat Ulang Tahun", 295),
            ("Sorai", "Nadin Amizah", "Kalah Bertaruh", 244),
            ("Komang", "Raim Laode", "Komang", 222),
            ("Sial", "Mahalini", "Fabula", 240),
            ("Rewrite The Stars", "Anne-Marie & James Arthur", "The Greatest Showman", 218),
            ("Shape of You", "Ed Sheeran", "Divide", 233),
            ("Blinding Lights", "The Weeknd", "After Hours", 200),
            ("As It Was", "Harry Styles", "Harry's House", 167),
            ("Lathi", "Weird Genius ft. Sara Fajira", "Lathi", 184),
            ("Runtuh", "Feby Putri ft. Fiersa Besari", "Riuh", 252),
            ("Cukup", "Ziva Magnolya", "Magnolya", 241),
            ("Glimpse of Us", "Joji", "SMITHEREENS", 233),
            ("Snooze", "SZA", "SOS", 201),
            ("Cruel Summer", "Taylor Swift", "Lover", 178),
            ("About You", "The 1975", "Being Funny", 326)
        ]

        var list: [IPodTrack] = []
        for idx in 0..<100 {
            let s = songs[idx % songs.count]
            let title = idx < songs.count ? s.title : "\(s.title) (\(idx / songs.count + 1))"
            let art = makeLowResArtwork(title: title, artist: s.artist, tag: "Song")
            let streamURL = URL(string: verifiedAudioStreams[idx % verifiedAudioStreams.count])
            list.append(makeTrack(
                id: "track_\(idx)_\(s.title)",
                title: title,
                artist: s.artist,
                album: s.album,
                duration: s.duration,
                assetURL: streamURL,
                artworkImage: art
            ))
        }
        allStreamingTracks = reshuffle ? list.shuffled() : list
    }

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