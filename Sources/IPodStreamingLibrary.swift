import Foundation
import UIKit
import MediaPlayer

struct IPodResolvedStream {
    let url: URL
    let userAgent: String
    let duration: TimeInterval?
    let fallbackCandidates: [(url: URL, userAgent: String)]
}

enum IPodStreamResolutionResult {
    case playable(IPodResolvedStream)
    case failed(reason: String)
}

private enum InnerTubeClient {
    case ios
    case android
    case iosMusic
    case webRemix
    case web
    case mweb

    var clientName: String {
        switch self {
        case .ios:      return "IOS"
        case .android:  return "ANDROID"
        case .iosMusic: return "IOS_MUSIC"
        case .webRemix: return "WEB_REMIX"
        case .web:      return "WEB"
        case .mweb:     return "MWEB"
        }
    }

    var clientId: String {
        switch self {
        case .ios:      return "5"
        case .android:  return "3"
        case .iosMusic: return "26"
        case .webRemix: return "67"
        case .web:      return "1"
        case .mweb:     return "2"
        }
    }

    var clientVersion: String {
        switch self {
        case .ios:      return "20.10.4"
        case .android:  return "20.10.38"
        case .iosMusic: return "7.29.3"
        case .webRemix: return "1.20260707.12.00"
        case .web:      return "2.20250312.04.00"
        case .mweb:     return "2.20260501.01.00"
        }
    }

    var userAgent: String {
        switch self {
        case .ios:
            return "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
        case .android:
            return "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip"
        case .iosMusic:
            return "com.google.ios.youtubemusic/7.29.3 (iPhone; U; CPU iPhone OS 12_5_8 like Mac OS X; en_US)"
        case .webRemix, .web:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        case .mweb:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1"
        }
    }

    func clientContext(visitorData: String?) -> [String: Any] {
        var ctx: [String: Any] = [
            "clientName": clientName,
            "clientVersion": clientVersion,
            "hl": "id",
            "gl": "ID"
        ]
        if let vd = visitorData, !vd.isEmpty {
            ctx["visitorData"] = vd
        }
        switch self {
        case .ios:
            ctx["deviceMake"] = "Apple"
            ctx["deviceModel"] = "iPhone16,2"
            ctx["osName"] = "iPhone"
            ctx["osVersion"] = "18.3.2.22D82"
        case .android:
            ctx["osName"] = "Android"
            ctx["osVersion"] = "11"
            ctx["androidSdkVersion"] = 30
        default:
            break
        }
        return ctx
    }
}

final class IPodStreamingLibrary {
    static let shared = IPodStreamingLibrary()
    static let pageSize: Int = 50

    private(set) var allStreamingTracks: [IPodTrack] = []
    private(set) var isFetchingSongs: Bool = false
    var onTrackArtworkLoaded: ((String, UIImage) -> Void)?

    private var videoIdByTrackId: [String: String] = [:]
    private var thumbnailURLByTrackId: [String: String] = [:]
    private var resolvedStreamCache: [String: IPodResolvedStream] = [:]
    private var artworkCache: [String: UIImage] = [:]
    private var visitorData: String?
    private var fetchGeneration: Int = 0

    private let songQueries = [
        "lagu indonesia populer official audio",
        "lagu indo hits terbaru official audio",
        "indonesian indie pop official audio",
        "pop hits song official audio",
        "indie music song official audio",
        "acoustic song official audio",
        "electronic music song official audio",
        "rnb soul song official audio",
        "alternative rock song official audio",
        "jazz chill song official audio",
        "lagu galau indonesia official audio",
        "kpop hits official audio",
        "city pop song official audio",
        "folk acoustic song official audio"
    ]
    private var queryIndex: Int = 0

    private init() {}

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

    func searchSongs(query: String, completion: @escaping (Bool) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            refreshTracks(completion: completion)
            return
        }

        isFetchingSongs = true
        fetchGeneration += 1
        let activeGen = fetchGeneration

        let searchQueries = [
            trimmed,
            "\(trimmed) official audio",
            "\(trimmed) album"
        ]

        let group = DispatchGroup()
        let lock = NSLock()
        var buckets: [[InnerTubeSongEntry]] = Array(repeating: [], count: searchQueries.count)

        for (i, q) in searchQueries.enumerated() {
            group.enter()
            let clients: [InnerTubeClient] = [.webRemix, .mweb, .iosMusic]
            searchInnerTube(query: q, clients: clients, index: 0) { entries in
                lock.lock()
                buckets[i] = entries
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            var merged: [InnerTubeSongEntry] = []
            var seenVideoIds = Set<String>()
            for bucket in buckets {
                for entry in bucket where !seenVideoIds.contains(entry.videoId) {
                    seenVideoIds.insert(entry.videoId)
                    merged.append(entry)
                }
            }

            let cappedEntries = Array(merged.prefix(Self.pageSize))
            var tracks: [IPodTrack] = []
            var idMap: [String: String] = [:]
            var thumbMap: [String: String] = [:]

            for (idx, entry) in cappedEntries.enumerated() {
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
                guard activeGen == self.fetchGeneration else {
                    completion(!self.allStreamingTracks.isEmpty)
                    return
                }
                self.isFetchingSongs = false
                for (k, v) in idMap { self.videoIdByTrackId[k] = v }
                for (k, v) in thumbMap { self.thumbnailURLByTrackId[k] = v }
                self.allStreamingTracks = tracks
                self.loadLowResThumbnailsAsync(for: self.allStreamingTracks, updateMainCatalog: true)
                completion(!tracks.isEmpty)
            }
        }
    }

    func fetchRecommendations(for track: IPodTrack, limit: Int = 20, completion: @escaping ([IPodTrack]) -> Void) {
        guard let videoId = videoIdByTrackId[track.id], !videoId.isEmpty,
              let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/next?prettyPrint=false") else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let client = InnerTubeClient.web
        let body: [String: Any] = [
            "context": [
                "client": client.clientContext(visitorData: visitorData)
            ],
            "videoId": videoId
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(client.clientId, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(client.clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let parsed = self.parseSongsFromSearchJSON(json)
                .filter { $0.videoId != videoId }
            let limited = Array(parsed.prefix(limit))

            var recTracks: [IPodTrack] = []
            var idMap: [String: String] = [:]
            var thumbMap: [String: String] = [:]

            for (idx, entry) in limited.enumerated() {
                let trackId = "innertube_\(entry.videoId)_rec_\(idx)"
                let placeholderArt = self.placeholderArtwork(seed: entry.videoId)
                let watchURL = URL(string: "https://m.youtube.com/watch?v=\(entry.videoId)")
                let recTrack = self.makeTrack(
                    id: trackId,
                    title: entry.title,
                    artist: entry.artist,
                    album: entry.album,
                    duration: 210,
                    assetURL: watchURL,
                    artworkImage: placeholderArt
                )
                recTracks.append(recTrack)
                idMap[trackId] = entry.videoId
                if let tURL = entry.thumbnailURL {
                    thumbMap[trackId] = tURL
                }
            }

            DispatchQueue.main.async {
                for (k, v) in idMap { self.videoIdByTrackId[k] = v }
                for (k, v) in thumbMap { self.thumbnailURLByTrackId[k] = v }
                self.loadLowResThumbnailsAsync(for: recTracks, updateMainCatalog: false)
                completion(recTracks)
            }
        }.resume()
    }

    func invalidateCachedURL(for track: IPodTrack) {
        resolvedStreamCache.removeValue(forKey: track.id)
    }

    func videoId(for track: IPodTrack) -> String? {
        if let mapped = videoIdByTrackId[track.id], !mapped.isEmpty {
            return mapped
        }
        if let url = track.assetURL,
           let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = comps.queryItems?.first(where: { $0.name == "v" })?.value,
           !v.isEmpty {
            return v
        }
        return nil
    }

    func fetchInnerTubeLyrics(forVideoId videoId: String, completion: @escaping ([(time: TimeInterval?, text: String)]?, Bool) -> Void) {
        guard !videoId.isEmpty,
              let nextURL = URL(string: "https://music.youtube.com/youtubei/v1/next?prettyPrint=false") else {
            completion(nil, false)
            return
        }

        let client = InnerTubeClient.webRemix
        var clientCtx = client.clientContext(visitorData: visitorData)
        clientCtx["originalUrl"] = "https://music.youtube.com/watch?v=\(videoId)"
        let nextBody: [String: Any] = [
            "context": ["client": clientCtx],
            "videoId": videoId
        ]

        var nextReq = URLRequest(url: nextURL)
        nextReq.httpMethod = "POST"
        nextReq.timeoutInterval = 8.0
        nextReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        nextReq.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        nextReq.setValue(client.clientId, forHTTPHeaderField: "X-YouTube-Client-Name")
        nextReq.setValue(client.clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        nextReq.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        nextReq.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        nextReq.httpBody = try? JSONSerialization.data(withJSONObject: nextBody)

        URLSession.shared.dataTask(with: nextReq) { [weak self] data, response, error in
            guard let self = self else {
                completion(nil, false)
                return
            }

            if error == nil,
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data),
               let lyricsBrowseId = self.findLyricsBrowseId(in: json) {
                self.fetchYouTubeMusicBrowseLyrics(browseId: lyricsBrowseId, client: client) { lines, isSynced in
                    if let lines = lines, !lines.isEmpty {
                        completion(lines, isSynced)
                    } else {
                        self.fetchYouTubeCaptionLyrics(videoId: videoId, completion: completion)
                    }
                }
                return
            }

            self.fetchYouTubeCaptionLyrics(videoId: videoId, completion: completion)
        }.resume()
    }

    private func findLyricsBrowseId(in root: Any) -> String? {
        if let dict = root as? [String: Any] {
            if let browseId = dict["browseId"] as? String, browseId.hasPrefix("MPLYt_") {
                return browseId
            }
            for (_, val) in dict {
                if let found = findLyricsBrowseId(in: val) {
                    return found
                }
            }
        } else if let arr = root as? [Any] {
            for item in arr {
                if let found = findLyricsBrowseId(in: item) {
                    return found
                }
            }
        }
        return nil
    }

    private func fetchYouTubeMusicBrowseLyrics(
        browseId: String,
        client: InnerTubeClient,
        completion: @escaping ([(time: TimeInterval?, text: String)]?, Bool) -> Void
    ) {
        guard let browseURL = URL(string: "https://music.youtube.com/youtubei/v1/browse?prettyPrint=false") else {
            completion(nil, false)
            return
        }

        let body: [String: Any] = [
            "context": ["client": client.clientContext(visitorData: visitorData)],
            "browseId": browseId
        ]
        var req = URLRequest(url: browseURL)
        req.httpMethod = "POST"
        req.timeoutInterval = 8.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(client.clientId, forHTTPHeaderField: "X-YouTube-Client-Name")
        req.setValue(client.clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        req.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                completion(nil, false)
                return
            }

            if let timed = self.extractTimedLyrics(from: json), !timed.isEmpty {
                completion(timed, true)
                return
            }
            if let plain = self.extractPlainDescriptionLyrics(from: json), !plain.isEmpty {
                completion(plain, false)
                return
            }
            completion(nil, false)
        }.resume()
    }

    private func extractTimedLyrics(from root: Any) -> [(time: TimeInterval?, text: String)]? {
        if let dict = root as? [String: Any] {
            if let model = dict["timedLyricsModel"] as? [String: Any],
               let lyricsData = model["lyricsData"] as? [[String: Any]] {
                var parsed: [(time: TimeInterval?, text: String)] = []
                for entry in lyricsData {
                    guard let line = (entry["lyricLine"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !line.isEmpty else { continue }
                    let cueRange = entry["cueRange"] as? [String: Any]
                    let startMsStr = cueRange?["startTimeMilliseconds"] as? String
                    let startMsNum = cueRange?["startTimeMilliseconds"] as? NSNumber
                    let startMs = startMsStr.flatMap(Double.init) ?? startMsNum?.doubleValue
                    let timeSec = startMs.map { $0 / 1000.0 }
                    parsed.append((time: timeSec, text: line))
                }
                if !parsed.isEmpty { return parsed }
            }
            for (_, val) in dict {
                if let found = extractTimedLyrics(from: val) { return found }
            }
        } else if let arr = root as? [Any] {
            for item in arr {
                if let found = extractTimedLyrics(from: item) { return found }
            }
        }
        return nil
    }

    private func extractPlainDescriptionLyrics(from root: Any) -> [(time: TimeInterval?, text: String)]? {
        if let dict = root as? [String: Any] {
            if let shelf = dict["musicDescriptionShelfRenderer"] as? [String: Any],
               let descText = extractText(from: shelf["description"]) {
                let lines = descText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { (time: nil as TimeInterval?, text: $0) }
                if !lines.isEmpty { return lines }
            }
            for (_, val) in dict {
                if let found = extractPlainDescriptionLyrics(from: val) { return found }
            }
        } else if let arr = root as? [Any] {
            for item in arr {
                if let found = extractPlainDescriptionLyrics(from: item) { return found }
            }
        }
        return nil
    }

    private func fetchYouTubeCaptionLyrics(
        videoId: String,
        completion: @escaping ([(time: TimeInterval?, text: String)]?, Bool) -> Void
    ) {
        guard let playerURL = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            completion(nil, false)
            return
        }
        let client = InnerTubeClient.web
        let body: [String: Any] = [
            "context": ["client": client.clientContext(visitorData: visitorData)],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        var req = URLRequest(url: playerURL)
        req.httpMethod = "POST"
        req.timeoutInterval = 8.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(client.clientId, forHTTPHeaderField: "X-YouTube-Client-Name")
        req.setValue(client.clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let captions = json["captions"] as? [String: Any],
                  let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
                  let tracks = renderer["captionTracks"] as? [[String: Any]],
                  !tracks.isEmpty else {
                completion(nil, false)
                return
            }

            // Prefer human-authored lyrics/captions over auto-generated ASR
            let preferred = tracks.first(where: { ($0["kind"] as? String) != "asr" && (($0["languageCode"] as? String) == "id" || ($0["languageCode"] as? String) == "en") })
                ?? tracks.first(where: { ($0["kind"] as? String) != "asr" })
                ?? tracks.first

            guard var baseUrlStr = preferred?["baseUrl"] as? String, !baseUrlStr.isEmpty else {
                completion(nil, false)
                return
            }
            if !baseUrlStr.contains("fmt=json3") {
                baseUrlStr += baseUrlStr.contains("?") ? "&fmt=json3" : "?fmt=json3"
            }
            guard let captionURL = URL(string: baseUrlStr) else {
                completion(nil, false)
                return
            }

            var capReq = URLRequest(url: captionURL)
            capReq.timeoutInterval = 8.0
            capReq.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
            URLSession.shared.dataTask(with: capReq) { cData, cResp, cErr in
                guard cErr == nil,
                      let cHttp = cResp as? HTTPURLResponse,
                      cHttp.statusCode == 200,
                      let cData = cData,
                      let cJson = try? JSONSerialization.jsonObject(with: cData) as? [String: Any],
                      let events = cJson["events"] as? [[String: Any]] else {
                    completion(nil, false)
                    return
                }

                var result: [(time: TimeInterval?, text: String)] = []
                for ev in events {
                    guard let startMs = ev["tStartMs"] as? Double,
                          let segs = ev["segs"] as? [[String: Any]] else { continue }
                    let rawText = segs.compactMap { $0["utf8"] as? String }
                        .joined()
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !rawText.isEmpty, rawText != "[Music]", rawText != "♪" else { continue }
                    result.append((time: startMs / 1000.0, text: rawText))
                }
                completion(result.isEmpty ? nil : result, !result.isEmpty)
            }.resume()
        }.resume()
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

    func resolvePlayableAudio(for track: IPodTrack, forceRefresh: Bool = false, preferAlternateClient: Bool = false, completion: @escaping (IPodStreamResolutionResult) -> Void) {
        if !forceRefresh && !preferAlternateClient, let cached = resolvedStreamCache[track.id] {
            completion(.playable(cached))
            return
        }

        guard let videoId = videoIdByTrackId[track.id], !videoId.isEmpty else {
            completion(.failed(reason: "Video ID InnerTube kosong"))
            return
        }

        let clients: [InnerTubeClient] = preferAlternateClient
            ? [.ios, .android, .iosMusic]
            : [.android, .ios, .iosMusic]
        resolvePlayerStream(videoId: videoId, clients: clients, index: 0, lastErrorReason: "No Direct Audio URL") { [weak self] result in
            switch result {
            case .playable(let stream):
                self?.resolvedStreamCache[track.id] = stream
                DispatchQueue.main.async { completion(.playable(stream)) }

            case .failed(let playerReason):
                self?.resolveFromMobileWatchPage(videoId: videoId) { watchResult in
                    switch watchResult {
                    case .playable(let wStream):
                        self?.resolvedStreamCache[track.id] = wStream
                        DispatchQueue.main.async { completion(.playable(wStream)) }
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
        isFetchingSongs = true
        fetchGeneration += 1
        let activeGen = fetchGeneration

        // Pick 5 distinct queries rotating through the pool so each entry/refresh gets a fresh 50-song mix
        var selectedQueries: [String] = []
        let batchCount = min(5, songQueries.count)
        for offset in 0..<batchCount {
            let idx = (queryIndex + offset) % songQueries.count
            selectedQueries.append(songQueries[idx])
        }
        queryIndex = (queryIndex + 3) % songQueries.count
        selectedQueries.shuffle()

        collectSongsBatch(queries: selectedQueries, targetCount: Self.pageSize) { [weak self] entries in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let orderedEntries = (reshuffle ? entries.shuffled() : entries.shuffled())
            let cappedEntries = Array(orderedEntries.prefix(Self.pageSize))

            var tracks: [IPodTrack] = []
            var idMap: [String: String] = [:]
            var thumbMap: [String: String] = [:]

            for (idx, entry) in cappedEntries.enumerated() {
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
                guard activeGen == self.fetchGeneration else {
                    completion(!self.allStreamingTracks.isEmpty)
                    return
                }
                self.isFetchingSongs = false
                for (k, v) in idMap { self.videoIdByTrackId[k] = v }
                for (k, v) in thumbMap { self.thumbnailURLByTrackId[k] = v }
                self.allStreamingTracks = tracks
                self.loadLowResThumbnailsAsync(for: self.allStreamingTracks, updateMainCatalog: true)
                completion(!tracks.isEmpty)
            }
        }
    }

    private func collectSongsBatch(
        queries: [String],
        targetCount: Int,
        completion: @escaping ([InnerTubeSongEntry]) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var merged: [InnerTubeSongEntry] = []
        var seenVideoIds = Set<String>()

        for q in queries {
            group.enter()
            let clients: [InnerTubeClient] = [.webRemix, .mweb, .iosMusic]
            searchInnerTube(query: q, clients: clients, index: 0) { entries in
                lock.lock()
                for entry in entries where !seenVideoIds.contains(entry.videoId) {
                    seenVideoIds.insert(entry.videoId)
                    merged.append(entry)
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            if merged.count >= targetCount {
                completion(merged)
                return
            }
            // Top-up wave if initial 5 queries returned fewer than 50 after filtering
            let extraQueries = self.songQueries.filter { !queries.contains($0) }.shuffled().prefix(3)
            if extraQueries.isEmpty {
                completion(merged)
                return
            }
            let topUpGroup = DispatchGroup()
            for q in extraQueries {
                topUpGroup.enter()
                self.searchInnerTube(query: q, clients: [.webRemix, .mweb], index: 0) { entries in
                    lock.lock()
                    for entry in entries where !seenVideoIds.contains(entry.videoId) {
                        seenVideoIds.insert(entry.videoId)
                        merged.append(entry)
                    }
                    lock.unlock()
                    topUpGroup.leave()
                }
            }
            topUpGroup.notify(queue: .global(qos: .userInitiated)) {
                completion(merged)
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
                "client": client.clientContext(visitorData: visitorData)
            ],
            "query": query
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(client.clientId, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(client.clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
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

            if let respCtx = json["responseContext"] as? [String: Any],
               let vd = respCtx["visitorData"] as? String, !vd.isEmpty {
                self.visitorData = vd
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
                        let rawSubtitle = texts.dropFirst().first ?? ""
                        if isNonSongSubtitle(rawSubtitle) {
                            return
                        }
                        let artist = cleanArtistName(from: rawSubtitle)
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
                        let rawArtist = extractText(from: dict["shortBylineText"] ?? dict["longBylineText"] ?? "")
                        let artist = cleanArtistName(from: rawArtist)
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

    private func isNonSongSubtitle(_ raw: String) -> Bool {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["playlist •", "profil •", "profile •", "artis •", "artist •", "tangga lagu •", "chart •", "episode •", "podcast •"]
        return prefixes.contains(where: { lower.hasPrefix($0) })
    }

    private func cleanArtistName(from raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "Unknown Artist" }
        let normalized = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
        let parts = normalized
            .components(separatedBy: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let ignoredExact: Set<String> = [
            "lagu", "song", "video", "music video", "single", "ep", "album",
            "artis", "artist", "profil", "profile", "tangga lagu", "chart",
            "podcast", "episode", "official audio"
        ]
        let ignoredContains = [
            "pemutaran", "ditonton", "views", "plays", "listeners",
            "audiens", "pelanggan", "subscribers", "tracks"
        ]

        for part in parts {
            let lower = part.lowercased()
            if ignoredExact.contains(lower) { continue }
            if ignoredContains.contains(where: { lower.contains($0) }) { continue }
            // Skip pure durations (e.g. "3:45" or "3.45") or 4-digit release years (e.g. "2024")
            if part.range(of: #"^\d{1,2}([:.]\d{2})+$"#, options: .regularExpression) != nil { continue }
            if part.range(of: #"^\d{4}$"#, options: .regularExpression) != nil { continue }
            return part
        }
        return parts.first ?? "Unknown Artist"
    }

    private func upgradeThumbnailURL(_ urlStr: String) -> String {
        var upgraded = urlStr
        if upgraded.contains("googleusercontent.com") {
            upgraded = upgraded.replacingOccurrences(
                of: #"=w\d+-h\d+[^&\s]*"#,
                with: "=w360-h360-l90-rj",
                options: .regularExpression
            )
            upgraded = upgraded.replacingOccurrences(
                of: #"=s\d+[^&\s]*"#,
                with: "=s360",
                options: .regularExpression
            )
        }
        return upgraded
    }

    private func extractThumbnailURL(from dict: [String: Any]) -> String? {
        if let thumbObj = dict["thumbnail"] as? [String: Any],
           let musicThumb = thumbObj["musicThumbnailRenderer"] as? [String: Any],
           let innerThumb = musicThumb["thumbnail"] as? [String: Any],
           let thumbs = innerThumb["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            return upgradeThumbnailURL(urlStr)
        }
        if let thumbObj = dict["thumbnail"] as? [String: Any],
           let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
           let last = thumbs.last,
           let urlStr = last["url"] as? String {
            return upgradeThumbnailURL(urlStr)
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
                "client": client.clientContext(visitorData: visitorData)
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
        request.setValue(client.clientId, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(client.clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
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

            let extraction = self.extractAudioStream(from: json, client: client)
            switch extraction {
            case .playable(let stream):
                completion(.playable(stream))
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

    private func extractAudioStream(from playerJSON: [String: Any], client: InnerTubeClient) -> IPodStreamResolutionResult {
        guard let streamingData = playerJSON["streamingData"] as? [String: Any] else {
            return .failed(reason: "Missing streamingData")
        }

        var durationSec: TimeInterval? = nil
        if let details = playerJSON["videoDetails"] as? [String: Any],
           let lenStr = details["lengthSeconds"] as? String,
           let parsed = Double(lenStr), parsed > 0 {
            durationSec = parsed
        }

        let adaptive = streamingData["adaptiveFormats"] as? [[String: Any]] ?? []
        let standard = streamingData["formats"] as? [[String: Any]] ?? []

        var candidates: [(url: URL, userAgent: String)] = []
        var seenURLs = Set<String>()

        func appendCandidate(_ urlStr: String?) {
            guard let s = urlStr, !s.isEmpty, !seenURLs.contains(s), let u = URL(string: s) else { return }
            seenURLs.insert(s)
            candidates.append((url: u, userAgent: client.userAgent))
        }

        // 1. Prefer HLS manifest or progressive MP4 (e.g. itag 18) first:
        //    YouTube caps adaptiveFormats (itag 140/139) at 1 MB (~59s) with HTTP 403 without a PO Token,
        //    whereas progressive MP4 (formats) and HLS stream continuously for the full track.
        if let hlsStr = streamingData["hlsManifestUrl"] as? String {
            appendCandidate(hlsStr)
        }

        let mp4Standard = standard.filter { fmt in
            let mime = (fmt["mimeType"] as? String ?? "").lowercased()
            return (mime.contains("video/mp4") || mime.contains("audio/mp4"))
                && (fmt["url"] as? String)?.isEmpty == false
        }.sorted {
            // Prefer smaller progressive MP4 (e.g. itag 18 / 360p) for faster audio buffering
            let b1 = $0["bitrate"] as? Int ?? Int.max
            let b2 = $1["bitrate"] as? Int ?? Int.max
            return b1 < b2
        }
        for fmt in mp4Standard {
            appendCandidate(fmt["url"] as? String)
            if durationSec == nil,
               let msStr = fmt["approxDurationMs"] as? String,
               let ms = Double(msStr), ms > 0 {
                durationSec = ms / 1000.0
            }
        }

        // 2. Fallback to adaptive audio/mp4 (AAC) only if progressive/HLS is unavailable
        let mp4AudioFormats = adaptive.filter { fmt in
            let mime = (fmt["mimeType"] as? String ?? "").lowercased()
            return mime.contains("audio/mp4") && (fmt["url"] as? String)?.isEmpty == false
        }.sorted {
            let b1 = $0["bitrate"] as? Int ?? 0
            let b2 = $1["bitrate"] as? Int ?? 0
            return b1 > b2
        }
        for fmt in mp4AudioFormats {
            appendCandidate(fmt["url"] as? String)
            if durationSec == nil,
               let msStr = fmt["approxDurationMs"] as? String,
               let ms = Double(msStr), ms > 0 {
                durationSec = ms / 1000.0
            }
        }

        guard let primary = candidates.first else {
            return .failed(reason: "No AVPlayer-compatible audio/mp4 URL")
        }

        let stream = IPodResolvedStream(
            url: primary.url,
            userAgent: primary.userAgent,
            duration: durationSec,
            fallbackCandidates: Array(candidates.dropFirst())
        )
        return .playable(stream)
    }

    private func resolveFromMobileWatchPage(videoId: String, completion: @escaping (IPodStreamResolutionResult) -> Void) {
        guard let url = URL(string: "https://m.youtube.com/watch?v=\(videoId)") else {
            completion(.failed(reason: "Watch URL Invalid"))
            return
        }
        let ua = InnerTubeClient.mweb.userAgent
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue(ua, forHTTPHeaderField: "User-Agent")

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
                #"https?://[^"\\\s]+mime=audio%2Fmp4[^"\\\s]+"#,
                #"https?://[^"\\\s]+mime=audio/mp4[^"\\\s]+"#
            ]
            for pat in patterns {
                if let regex = try? NSRegularExpression(pattern: pat),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range, in: html) {
                    let decoded = String(html[range])
                        .replacingOccurrences(of: "\\u0026", with: "&")
                        .replacingOccurrences(of: "\\/", with: "/")
                    if let audioURL = URL(string: decoded) {
                        let stream = IPodResolvedStream(
                            url: audioURL,
                            userAgent: ua,
                            duration: nil,
                            fallbackCandidates: []
                        )
                        completion(.playable(stream))
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

    private func loadLowResThumbnailsAsync(for tracks: [IPodTrack], updateMainCatalog: Bool) {
        for (idx, track) in tracks.enumerated() {
            guard let thumbStr = thumbnailURLByTrackId[track.id],
                  let url = URL(string: thumbStr) else { continue }
            if let cached = artworkCache[thumbStr] {
                if updateMainCatalog {
                    replaceTrackArtwork(at: idx, expectedId: track.id, image: cached)
                }
                onTrackArtworkLoaded?(track.id, cached)
                continue
            }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let rawImg = UIImage(data: data) else { return }
                let crispImg = self.downsampleImage(rawImg, targetSide: 320)
                DispatchQueue.main.async {
                    self.artworkCache[thumbStr] = crispImg
                    if updateMainCatalog {
                        self.replaceTrackArtwork(at: idx, expectedId: track.id, image: crispImg)
                    }
                    self.onTrackArtworkLoaded?(track.id, crispImg)
                }
            }.resume()
        }
    }

    private func downsampleImage(_ image: UIImage, targetSide: CGFloat) -> UIImage {
        let targetSize = CGSize(width: targetSide, height: targetSide)
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        let imgSize = image.size
        guard imgSize.width > 0 && imgSize.height > 0 else {
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            return UIGraphicsGetImageFromCurrentImageContext() ?? image
        }
        // Aspect-fill centered crop so 16:9 thumbnails stay sharp and undistorted in square CoverFlow
        let scale = max(targetSide / imgSize.width, targetSide / imgSize.height)
        let drawW = imgSize.width * scale
        let drawH = imgSize.height * scale
        let drawRect = CGRect(
            x: (targetSide - drawW) / 2.0,
            y: (targetSide - drawH) / 2.0,
            width: drawW,
            height: drawH
        )
        image.draw(in: drawRect)
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    private func placeholderArtwork(seed: String) -> UIImage? {
        if let cached = artworkCache[seed] {
            return cached
        }
        let hue = CGFloat(abs(seed.hashValue) % 360) / 360.0
        let size = CGSize(width: 240, height: 240)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        UIColor(hue: hue, saturation: 0.50, brightness: 0.28, alpha: 1.0).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 72, weight: .bold),
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