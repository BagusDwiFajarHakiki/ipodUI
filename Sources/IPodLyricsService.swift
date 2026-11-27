import Foundation
import AVFoundation
import MediaPlayer

struct IPodLyricLine {
    let time: TimeInterval?
    let text: String
}

struct IPodTrackLyrics {
    let trackId: String
    let lines: [IPodLyricLine]
    let isSynced: Bool
    let source: String
}

final class IPodLyricsService {
    static let shared = IPodLyricsService()

    private var cache: [String: IPodTrackLyrics] = [:]
    private var inFlightCallbacks: [String: [(IPodTrackLyrics?) -> Void]] = [:]
    private let stateLock = NSLock()

    private init() {}

    func cachedLyrics(for trackId: String) -> IPodTrackLyrics? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return cache[trackId]
    }

    func fetchLyrics(for track: IPodTrack, completion: @escaping (IPodTrackLyrics?) -> Void) {
        if let cached = cachedLyrics(for: track.id) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        stateLock.lock()
        if inFlightCallbacks[track.id] != nil {
            inFlightCallbacks[track.id]?.append(completion)
            stateLock.unlock()
            return
        }
        inFlightCallbacks[track.id] = [completion]
        stateLock.unlock()

        func finish(with lyrics: IPodTrackLyrics?) {
            self.stateLock.lock()
            if let valid = lyrics, !valid.lines.isEmpty {
                self.cache[track.id] = valid
            }
            let callbacks = self.inFlightCallbacks.removeValue(forKey: track.id) ?? []
            self.stateLock.unlock()
            DispatchQueue.main.async {
                for cb in callbacks {
                    cb(lyrics)
                }
            }
        }

        // 1. Local embedded lyrics (MPMediaItem / ID3 USLT)
        if let localLyrics = extractLocalEmbeddedLyrics(for: track) {
            finish(with: localLyrics)
            return
        }

        // 2. LRCLIB exact + search -> 3. YouTube Music InnerTube Lyrics / Captions
        queryLRCLIB(for: track) { [weak self] lrcResult in
            if let lrcResult = lrcResult, !lrcResult.lines.isEmpty {
                finish(with: lrcResult)
                return
            }

            guard let self = self else {
                finish(with: nil)
                return
            }

            if let videoId = IPodStreamingLibrary.shared.videoId(for: track) {
                IPodStreamingLibrary.shared.fetchInnerTubeLyrics(forVideoId: videoId) { rawLines, isSynced in
                    guard let rawLines = rawLines, !rawLines.isEmpty else {
                        finish(with: nil)
                        return
                    }
                    let mapped = rawLines.compactMap { entry -> IPodLyricLine? in
                        let cleaned = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleaned.isEmpty else { return nil }
                        return IPodLyricLine(time: entry.time, text: cleaned)
                    }
                    guard !mapped.isEmpty else {
                        finish(with: nil)
                        return
                    }
                    let trackLyrics = IPodTrackLyrics(
                        trackId: track.id,
                        lines: mapped,
                        isSynced: isSynced,
                        source: isSynced ? "YouTube Synced" : "YouTube Music"
                    )
                    finish(with: trackLyrics)
                }
            } else {
                finish(with: nil)
            }
        }
    }

    // MARK: - Local Embedded Lyrics
    private func extractLocalEmbeddedLyrics(for track: IPodTrack) -> IPodTrackLyrics? {
        if let itemLyrics = track.mediaItem?.value(forProperty: MPMediaItemPropertyLyrics) as? String,
           !itemLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parsed = parseLyricsText(itemLyrics)
            if !parsed.lines.isEmpty {
                return IPodTrackLyrics(trackId: track.id, lines: parsed.lines, isSynced: parsed.isSynced, source: "Local")
            }
        }
        if let url = track.assetURL, url.isFileURL {
            let asset = AVURLAsset(url: url)
            if let embedded = asset.lyrics, !embedded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let parsed = parseLyricsText(embedded)
                if !parsed.lines.isEmpty {
                    return IPodTrackLyrics(trackId: track.id, lines: parsed.lines, isSynced: parsed.isSynced, source: "Local")
                }
            }
        }
        return nil
    }

    // MARK: - LRCLIB Pipeline
    private func queryLRCLIB(for track: IPodTrack, completion: @escaping (IPodTrackLyrics?) -> Void) {
        let normalized = normalizeTitleAndArtist(title: track.title, artist: track.artist)
        let title = normalized.title
        let artist = normalized.artist

        guard !title.isEmpty else {
            completion(nil)
            return
        }

        // Step A: /api/get when artist is meaningful
        if !artist.isEmpty {
            requestLRCLIBGet(trackId: track.id, title: title, artist: artist, album: track.album, duration: track.duration) { [weak self] exact in
                if let exact = exact {
                    completion(exact)
                    return
                }
                self?.searchLRCLIB(track: track, cleanTitle: title, cleanArtist: artist, completion: completion)
            }
        } else {
            searchLRCLIB(track: track, cleanTitle: title, cleanArtist: artist, completion: completion)
        }
    }

    private func requestLRCLIBGet(
        trackId: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        completion: @escaping (IPodTrackLyrics?) -> Void
    ) {
        var comps = URLComponents(string: "https://lrclib.net/api/get")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if !album.isEmpty && album != "Streaming" && album != "YouTube Music" && album != "Unknown Album" {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if duration > 10 && duration < 3600 {
            items.append(URLQueryItem(name: "duration", value: String(Int(round(duration)))))
        }
        comps?.queryItems = items

        guard let url = comps?.url else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue("iPodUI/1.0 (https://github.com)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data = data,
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil)
                return
            }
            completion(self.parseLRCLIBItem(dict, trackId: trackId))
        }.resume()
    }

    private func searchLRCLIB(
        track: IPodTrack,
        cleanTitle: String,
        cleanArtist: String,
        completion: @escaping (IPodTrackLyrics?) -> Void
    ) {
        var queries: [[URLQueryItem]] = []
        if !cleanArtist.isEmpty {
            queries.append([
                URLQueryItem(name: "track_name", value: cleanTitle),
                URLQueryItem(name: "artist_name", value: cleanArtist)
            ])
            queries.append([
                URLQueryItem(name: "q", value: "\(cleanTitle) \(cleanArtist)")
            ])
        }
        queries.append([
            URLQueryItem(name: "q", value: cleanTitle)
        ])

        runLRCLIBSearchChain(queries: queries, index: 0, track: track, cleanTitle: cleanTitle, cleanArtist: cleanArtist, completion: completion)
    }

    private func runLRCLIBSearchChain(
        queries: [[URLQueryItem]],
        index: Int,
        track: IPodTrack,
        cleanTitle: String,
        cleanArtist: String,
        completion: @escaping (IPodTrackLyrics?) -> Void
    ) {
        guard queries.indices.contains(index) else {
            completion(nil)
            return
        }

        var comps = URLComponents(string: "https://lrclib.net/api/search")
        comps?.queryItems = queries[index]
        guard let url = comps?.url else {
            runLRCLIBSearchChain(queries: queries, index: index + 1, track: track, cleanTitle: cleanTitle, cleanArtist: cleanArtist, completion: completion)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue("iPodUI/1.0 (https://github.com)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if error == nil,
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               let data = data,
               let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let best = self.pickBestLRCLIBCandidate(items, expectedTitle: cleanTitle, expectedArtist: cleanArtist, expectedDuration: track.duration),
               let parsed = self.parseLRCLIBItem(best, trackId: track.id) {
                completion(parsed)
                return
            }

            self.runLRCLIBSearchChain(
                queries: queries,
                index: index + 1,
                track: track,
                cleanTitle: cleanTitle,
                cleanArtist: cleanArtist,
                completion: completion
            )
        }.resume()
    }

    private func pickBestLRCLIBCandidate(
        _ items: [[String: Any]],
        expectedTitle: String,
        expectedArtist: String,
        expectedDuration: TimeInterval
    ) -> [String: Any]? {
        let lowerTitle = expectedTitle.lowercased()
        let lowerArtist = expectedArtist.lowercased()
        let artistTokens = lowerArtist.split(separator: " ").map(String.init).filter { $0.count >= 2 }

        var bestItem: [String: Any]?
        var bestScore: Int = -1000

        for item in items {
            let synced = (item["syncedLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let plain = (item["plainLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isInstrumental = (item["instrumental"] as? Bool) ?? false
            if isInstrumental || (synced.isEmpty && plain.isEmpty) { continue }

            var score = 0
            if !synced.isEmpty { score += 50 }

            let candTitle = (item["trackName"] as? String ?? "").lowercased()
            let candArtist = (item["artistName"] as? String ?? "").lowercased()

            if candTitle == lowerTitle {
                score += 40
            } else if candTitle.contains(lowerTitle) || lowerTitle.contains(candTitle) {
                score += 20
            }

            if !lowerArtist.isEmpty {
                if candArtist == lowerArtist {
                    score += 35
                } else if candArtist.contains(lowerArtist) || lowerArtist.contains(candArtist) {
                    score += 20
                } else if artistTokens.contains(where: { candArtist.contains($0) }) {
                    score += 10
                } else {
                    score -= 15
                }
            }

            if expectedDuration > 15, let candDur = item["duration"] as? Double, candDur > 15 {
                let diff = abs(candDur - expectedDuration)
                if diff <= 4 {
                    score += 25
                } else if diff <= 12 {
                    score += 12
                } else if diff > 35 {
                    score -= 25
                }
            }

            if score > bestScore {
                bestScore = score
                bestItem = item
            }
        }

        return bestScore > 0 ? bestItem : nil
    }

    private func parseLRCLIBItem(_ dict: [String: Any], trackId: String) -> IPodTrackLyrics? {
        if let synced = dict["syncedLyrics"] as? String,
           !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = parseLRC(synced)
            if !lines.isEmpty {
                return IPodTrackLyrics(trackId: trackId, lines: lines, isSynced: true, source: "LRCLIB")
            }
        }
        if let plain = dict["plainLyrics"] as? String,
           !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = parsePlainLyrics(plain)
            if !lines.isEmpty {
                return IPodTrackLyrics(trackId: trackId, lines: lines, isSynced: false, source: "LRCLIB")
            }
        }
        return nil
    }

    // MARK: - LRC & Normalization Helpers
    private func parseLyricsText(_ text: String) -> (lines: [IPodLyricLine], isSynced: Bool) {
        let lrcLines = parseLRC(text)
        if !lrcLines.isEmpty {
            return (lrcLines, true)
        }
        return (parsePlainLyrics(text), false)
    }

    private func parseLRC(_ raw: String) -> [IPodLyricLine] {
        guard let tagRegex = try? NSRegularExpression(pattern: "\\[(\\d{1,3}):(\\d{2})(?:[\\.:](\\d{1,3}))?\\]", options: []) else {
            return []
        }

        var result: [IPodLyricLine] = []
        let rawLines = raw.components(separatedBy: .newlines)

        for line in rawLines {
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            let matches = tagRegex.matches(in: line, options: [], range: fullRange)
            guard !matches.isEmpty else { continue }

            let lastEnd = matches.last!.range.location + matches.last!.range.length
            let textPart = nsLine.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !textPart.isEmpty else { continue }

            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let minStr = nsLine.substring(with: match.range(at: 1))
                let secStr = nsLine.substring(with: match.range(at: 2))
                var fracSeconds: TimeInterval = 0
                if match.range(at: 3).location != NSNotFound {
                    let fracStr = nsLine.substring(with: match.range(at: 3))
                    if let fracVal = Double(fracStr) {
                        fracSeconds = fracVal / pow(10.0, Double(fracStr.count))
                    }
                }
                if let m = Double(minStr), let s = Double(secStr) {
                    let timestamp = m * 60.0 + s + fracSeconds
                    result.append(IPodLyricLine(time: timestamp, text: textPart))
                }
            }
        }

        return result.sorted { ($0.time ?? 0) < ($1.time ?? 0) }
    }

    private func parsePlainLyrics(_ raw: String) -> [IPodLyricLine] {
        return raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { IPodLyricLine(time: nil, text: $0) }
    }

    private func normalizeTitleAndArtist(title: String, artist: String) -> (title: String, artist: String) {
        var cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        let genericArtists: Set<String> = ["", "youtube", "youtube music", "unknown artist", "various artists", "topic"]
        if genericArtists.contains(cleanArtist.lowercased()) {
            cleanArtist = ""
        }
        if cleanArtist.hasSuffix(" - Topic") {
            cleanArtist = String(cleanArtist.dropLast(" - Topic".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Remove common YouTube suffixes in brackets/parentheses
        let junkPatterns = [
            "\\s*[\\(\\[]\\s*(?:official\\s*(?:music\\s*)?(?:video|audio|lyric(?:s)?(?:\\s*video)?|visualizer|mv)|lyric(?:s)?\\s*video|audio\\s*only|hd|hq|4k|live(?:\\s*performance)?|remaster(?:ed)?(?:\\s*\\d{4})?)\\s*[\\)\\]]",
            "\\s*[\\(\\[]\\s*(?:feat\\.|ft\\.|featuring)\\s+[^\\)\\]]+[\\)\\]]"
        ]
        for pattern in junkPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (cleanTitle as NSString).length)
                cleanTitle = regex.stringByReplacingMatches(in: cleanTitle, options: [], range: range, withTemplate: "")
            }
        }

        // If artist is empty and title looks like "Artist - Song Title", split it
        if cleanArtist.isEmpty, let dashRange = cleanTitle.range(of: " - ") {
            let left = String(cleanTitle[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(cleanTitle[dashRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !left.isEmpty && !right.isEmpty {
                cleanArtist = left
                cleanTitle = right
            }
        }

        // Also strip "feat. ..." from artist for stricter /api/get matches
        if let featRegex = try? NSRegularExpression(pattern: "\\s+(?:feat\\.|ft\\.|featuring|x|&|,)\\s+.*$", options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: (cleanArtist as NSString).length)
            cleanArtist = featRegex.stringByReplacingMatches(in: cleanArtist, options: [], range: range, withTemplate: "")
        }

        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanArtist = cleanArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleanTitle, cleanArtist)
    }
}
