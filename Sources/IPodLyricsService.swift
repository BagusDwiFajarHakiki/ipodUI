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

        func finish(with rawLyrics: IPodTrackLyrics?) {
            func deliver(_ finalLyrics: IPodTrackLyrics?) {
                self.stateLock.lock()
                if let valid = finalLyrics, !valid.lines.isEmpty {
                    self.cache[track.id] = valid
                }
                let callbacks = self.inFlightCallbacks.removeValue(forKey: track.id) ?? []
                self.stateLock.unlock()
                DispatchQueue.main.async {
                    for cb in callbacks {
                        cb(finalLyrics)
                    }
                }
            }

            guard let valid = rawLyrics, !valid.lines.isEmpty else {
                deliver(rawLyrics)
                return
            }

            let hasNonLatin = valid.lines.contains { self.containsNonLatinLetters($0.text) }
            guard hasNonLatin else {
                let cleanedLines = valid.lines.map {
                    IPodLyricLine(time: $0.time, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                deliver(IPodTrackLyrics(
                    trackId: valid.trackId,
                    lines: cleanedLines,
                    isSynced: valid.isSynced,
                    source: valid.source
                ))
                return
            }

            self.romanizeLinesAsync(valid.lines) { romanizedLines in
                deliver(IPodTrackLyrics(
                    trackId: valid.trackId,
                    lines: romanizedLines,
                    isSynced: valid.isSynced,
                    source: valid.source
                ))
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

    private func containsNonLatinLetters(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if CharacterSet.letters.contains(scalar) && scalar.value > 0x024F {
                return true
            }
        }
        return false
    }

    private func containsArabicLetters(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (v >= 0x0600 && v <= 0x06FF) ||
               (v >= 0x0750 && v <= 0x077F) ||
               (v >= 0x08A0 && v <= 0x08FF) ||
               (v >= 0xFB50 && v <= 0xFDFF) ||
               (v >= 0xFE70 && v <= 0xFEFF) {
                return true
            }
        }
        return false
    }

    private func romanizeLinesAsync(_ lines: [IPodLyricLine], completion: @escaping ([IPodLyricLine]) -> Void) {
        var seen = Set<String>()
        var arabicUnique: [String] = []
        var otherUnique: [String] = []

        for line in lines {
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, containsNonLatinLetters(trimmed), !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            if containsArabicLetters(trimmed) {
                arabicUnique.append(trimmed)
            } else {
                otherUnique.append(trimmed)
            }
        }

        guard !arabicUnique.isEmpty || !otherUnique.isEmpty else {
            completion(lines.map { IPodLyricLine(time: $0.time, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) })
            return
        }

        let group = DispatchGroup()
        let mapLock = NSLock()
        var remoteMap: [String: String] = [:]

        func enqueueBatches(for items: [String], sourceLang: String, isArabic: Bool) {
            let batches = makeTransliterationBatches(items, maxLines: 30, maxUTF8Bytes: 1400)
            for batch in batches {
                group.enter()
                fetchGoogleRomanizationBatch(batch, sourceLang: sourceLang) { translated in
                    if let translated = translated, translated.count == batch.count {
                        mapLock.lock()
                        for (src, rawOut) in zip(batch, translated) {
                            let polished = self.cleanGoogleRomanizedLine(rawOut, original: src, isArabic: isArabic)
                            if !polished.isEmpty {
                                remoteMap[src] = polished
                            }
                        }
                        mapLock.unlock()
                    }
                    group.leave()
                }
            }
        }

        enqueueBatches(for: arabicUnique, sourceLang: "ar", isArabic: true)
        enqueueBatches(for: otherUnique, sourceLang: "auto", isArabic: false)

        group.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
            let finalLines: [IPodLyricLine] = lines.map { line in
                let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let remote = remoteMap[trimmed], !remote.isEmpty {
                    return IPodLyricLine(time: line.time, text: remote)
                }
                return IPodLyricLine(time: line.time, text: self.romanizeLyricLineIfNeeded(trimmed))
            }
            completion(finalLines)
        }
    }

    private func makeTransliterationBatches(_ lines: [String], maxLines: Int, maxUTF8Bytes: Int) -> [[String]] {
        var batches: [[String]] = []
        var current: [String] = []
        var currentBytes = 0

        for line in lines {
            let lineBytes = line.utf8.count + 1
            if !current.isEmpty && (current.count >= maxLines || currentBytes + lineBytes > maxUTF8Bytes) {
                batches.append(current)
                current = []
                currentBytes = 0
            }
            current.append(line)
            currentBytes += lineBytes
        }
        if !current.isEmpty {
            batches.append(current)
        }
        return batches
    }

    private func formURLEncoded(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func fetchGoogleRomanizationBatch(
        _ lines: [String],
        sourceLang: String,
        completion: @escaping ([String]?) -> Void
    ) {
        guard !lines.isEmpty,
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(sourceLang)&tl=en&dt=rm") else {
            completion(nil)
            return
        }

        let joinedInput = lines.joined(separator: "\n")
        let bodyString = "q=" + formURLEncoded(joinedInput)
        guard let bodyData = bodyString.data(using: .utf8) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 4.5
        request.httpBody = bodyData
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data = data,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let segments = root.first as? [[Any]] else {
                completion(nil)
                return
            }

            var combined = ""
            for seg in segments {
                if seg.count > 3, let part = seg[3] as? String {
                    combined += part
                }
            }
            guard !combined.isEmpty else {
                completion(nil)
                return
            }

            let splitLines = combined.components(separatedBy: "\n")
            guard splitLines.count == lines.count else {
                completion(nil)
                return
            }
            completion(splitLines)
        }.resume()
    }

    private func cleanGoogleRomanizedLine(_ raw: String, original: String, isArabic: Bool) -> String {
        var text = raw.applyingTransform(.stripDiacritics, reverse: false) ?? raw

        if isArabic {
            var existingLatinWords = Set<String>()
            if let wordRegex = try? NSRegularExpression(pattern: "[A-Za-z]+", options: []) {
                let nsOrig = original as NSString
                let matches = wordRegex.matches(in: original, options: [], range: NSRange(location: 0, length: nsOrig.length))
                for m in matches {
                    existingLatinWords.insert(nsOrig.substring(with: m.range).lowercased())
                }
            }

            let punctSet = CharacterSet.punctuationCharacters.union(.symbols)
            let tokens = text.components(separatedBy: .whitespaces)
            var adjustedTokens: [String] = []
            adjustedTokens.reserveCapacity(tokens.count)

            for tok in tokens {
                guard !tok.isEmpty else { continue }
                let coreLower = tok.trimmingCharacters(in: punctSet).lowercased()
                if !coreLower.isEmpty && existingLatinWords.contains(coreLower) {
                    adjustedTokens.append(tok)
                    continue
                }

                // In Google dt=rm Arabic output, 'e'/'E' encodes Arabic Ayn (ع)
                var fixed = tok.replacingOccurrences(of: "e", with: "'")
                    .replacingOccurrences(of: "E", with: "'")

                if let leadingApos = try? NSRegularExpression(pattern: "(?:^|(?<=[\\(\\[\"']))'+", options: []) {
                    let r = NSRange(location: 0, length: (fixed as NSString).length)
                    fixed = leadingApos.stringByReplacingMatches(in: fixed, options: [], range: r, withTemplate: "")
                }
                if let trailingDoubleA = try? NSRegularExpression(pattern: "aa(?=$|[^A-Za-z])", options: [.caseInsensitive]) {
                    let r = NSRange(location: 0, length: (fixed as NSString).length)
                    fixed = trailingDoubleA.stringByReplacingMatches(in: fixed, options: [], range: r, withTemplate: "a")
                }

                adjustedTokens.append(fixed)
            }
            text = adjustedTokens.joined(separator: " ")
        }

        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = text.first, first.isLowercase {
            text = String(first).uppercased() + text.dropFirst()
        }
        return text
    }

    private func romanizeLyricLineIfNeeded(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsNonLatinLetters(trimmed) else {
            return trimmed
        }

        if containsArabicLetters(trimmed) {
            return romanizeArabicOffline(trimmed)
        }

        var latin = trimmed.applyingTransform(.toLatin, reverse: false) ?? trimmed

        let replacements: [(String, String)] = [
            ("Č", "Ch"), ("č", "ch"),
            ("Š", "Sh"), ("š", "sh"),
            ("Ž", "Zh"), ("ž", "zh"),
            ("Ŝ", "Shch"), ("ŝ", "shch"),
            ("Û", "Yu"), ("û", "yu"),
            ("Â", "Ya"), ("â", "ya"),
            ("Ë", "Yo"), ("ë", "yo"),
            ("Ǧ", "Gh"), ("ǧ", "gh"),
            ("Ḫ", "Kh"), ("ḫ", "kh"),
            ("Ṯ", "Th"), ("ṯ", "th"),
            ("Ḏ", "Dh"), ("ḏ", "dh"),
            ("\u{02B9}", ""), ("\u{02BA}", ""),
            ("\u{02BF}", "'"), ("\u{02BB}", "'"), ("\u{02BE}", "")
        ]
        for (src, dst) in replacements {
            if latin.contains(src) {
                latin = latin.replacingOccurrences(of: src, with: dst)
            }
        }

        if let stripped = latin.applyingTransform(.stripDiacritics, reverse: false) {
            latin = stripped
        }

        while latin.contains("  ") {
            latin = latin.replacingOccurrences(of: "  ", with: " ")
        }
        latin = latin.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = latin.first, first.isLowercase {
            latin = String(first).uppercased() + latin.dropFirst()
        }
        return latin.isEmpty ? trimmed : latin
    }

    private func romanizeArabicOffline(_ text: String) -> String {
        let commonWords: [String: String] = [
            "الله": "Allah", "لله": "lillah", "والله": "wallah", "محمد": "Muhammad",
            "رحمن": "rahman", "رحيم": "rahim", "سبحان": "subhan", "الحمد": "alhamdu",
            "حبيبي": "habibi", "حبيب": "habib", "قلبي": "qalbi", "قلب": "qalb",
            "روحي": "ruhi", "روح": "ruh", "عمري": "umri", "عمر": "umar",
            "عيني": "aini", "عين": "ain", "عيوني": "uyuni", "نور": "nur",
            "سلام": "salam", "السلام": "assalam", "عليكم": "alaykum", "يا": "ya",
            "في": "fi", "من": "min", "علي": "ali", "على": "ala",
            "الى": "ila", "عن": "an", "مع": "ma'a", "معاك": "ma'ak",
            "معايا": "ma'aya", "انا": "ana", "انت": "anta", "انتي": "anti",
            "هو": "huwa", "هي": "hiya", "نحن": "nahnu", "لو": "law",
            "كل": "kull", "بس": "bas", "مش": "mish", "عشان": "ashan",
            "ليه": "leh", "فين": "fein", "ايه": "eh", "بحبك": "bahebbak",
            "احبك": "uhibbuk", "الدنيا": "addunya", "دنيا": "dunya", "جنة": "jannah",
            "الليل": "allayl", "ليلي": "laili", "نهار": "nahar", "شمس": "shams",
            "قمر": "qamar", "صبر": "sabr", "شوق": "shawq", "فرح": "farah",
            "حزن": "huzn", "كلام": "kalam", "بكرة": "bukra", "اليوم": "alyawm",
            "بيني": "bayni", "بيننا": "baynana", "عني": "anni", "بعيد": "ba'id",
            "قريب": "qarib", "غالي": "ghali", "مشتاق": "mushtaq", "سعيد": "sa'id",
            "تعال": "ta'al", "حياة": "hayah", "حياتي": "hayati", "زمان": "zaman",
            "مكان": "makan", "نفس": "nafs", "نفسي": "nafsi", "رب": "rabb",
            "ربي": "rabbi", "لا": "la", "ما": "ma", "و": "wa",
            "قد": "qad", "كان": "kan", "يكون": "yakun", "غير": "ghayr",
            "تحت": "taht", "فوق": "fawq", "قبل": "qabl", "بعد": "ba'd",
            "حتى": "hatta", "ابدا": "abadan", "دايما": "dayman", "كثير": "kathir",
            "كبير": "kabir", "صغير": "saghir", "جميل": "jamil", "ممكن": "mumkin",
            "لازم": "lazim", "عندي": "indi", "عندك": "indak", "عنده": "indahu",
            "صدري": "sadri", "قرآن": "quran", "قران": "quran", "ساعدني": "sa'idni"
        ]

        let consonantMap: [Unicode.Scalar: String] = [
            "ب": "b", "ت": "t", "ث": "th", "ج": "j", "ح": "h", "خ": "kh",
            "د": "d", "ذ": "dh", "ر": "r", "ز": "z", "س": "s", "ش": "sh",
            "ص": "s", "ض": "d", "ط": "t", "ظ": "z", "ع": "'", "غ": "gh",
            "ف": "f", "ق": "q", "ك": "k", "ل": "l", "م": "m", "ن": "n",
            "ه": "h", "ة": "ah", "ء": "'"
        ]

        func isArabicLetter(_ s: Unicode.Scalar) -> Bool {
            let v = s.value
            return (v >= 0x0621 && v <= 0x064A) || (v >= 0x0671 && v <= 0x06D3)
        }

        func normalizeArabicWordKey(_ w: String) -> String {
            var out = ""
            for scalar in w.unicodeScalars {
                let v = scalar.value
                // Skip tatweel and harakat diacritics
                if v == 0x0640 || (v >= 0x064B && v <= 0x065F) || v == 0x0670 {
                    continue
                }
                switch scalar {
                case "أ", "إ", "آ", "ٱ": out.append("ا")
                default: out.unicodeScalars.append(scalar)
                }
            }
            return out
        }

        func romanizeArabicWord(_ word: String) -> String {
            let key = normalizeArabicWordKey(word)
            if let hit = commonWords[key] {
                return hit
            }
            if !word.unicodeScalars.contains(where: { isArabicLetter($0) }) {
                return word
            }

            let scalars = Array(word.unicodeScalars.filter { $0.value != 0x0640 })
            var out = ""
            var idx = 0
            var pendingConsonantVowel = false
            var lastConsonant = ""

            if scalars.count >= 3 && (scalars[0] == "ا" || scalars[0] == "ٱ") && scalars[1] == "ل" {
                out = "al"
                idx = 2
            }

            while idx < scalars.count {
                let s = scalars[idx]
                switch s.value {
                case 0x064E: // fatha
                    out += "a"; pendingConsonantVowel = false
                case 0x064F: // damma
                    out += "u"; pendingConsonantVowel = false
                case 0x0650: // kasra
                    out += "i"; pendingConsonantVowel = false
                case 0x064B: // fathatan
                    out += "an"; pendingConsonantVowel = false
                case 0x064C: // dammatan
                    out += "un"; pendingConsonantVowel = false
                case 0x064D: // kasratan
                    out += "in"; pendingConsonantVowel = false
                case 0x0652: // sukun
                    pendingConsonantVowel = false
                case 0x0651: // shadda
                    if !lastConsonant.isEmpty { out += lastConsonant }
                case 0x0670: // dagger alif
                    out += "a"; pendingConsonantVowel = false
                default:
                    if s == "ا" || s == "آ" || s == "أ" || s == "إ" || s == "ٱ" || s == "ى" {
                        if idx == 0 && (s == "ا" || s == "أ" || s == "إ") {
                            out += "a"
                        } else if !out.hasSuffix("a") {
                            out += "a"
                        }
                        pendingConsonantVowel = false
                        lastConsonant = ""
                    } else if s == "و" {
                        if pendingConsonantVowel {
                            out += "u"
                        } else {
                            out += (idx == 0) ? "w" : "u"
                        }
                        pendingConsonantVowel = false
                        lastConsonant = ""
                    } else if s == "ي" || s == "ئ" {
                        if pendingConsonantVowel {
                            out += "i"
                        } else {
                            out += (idx == 0) ? "y" : "i"
                        }
                        pendingConsonantVowel = false
                        lastConsonant = ""
                    } else if let mapped = consonantMap[s] {
                        if pendingConsonantVowel && mapped != "'" && mapped != "ah" {
                            out += "a"
                        }
                        out += mapped
                        pendingConsonantVowel = (mapped != "'" && mapped != "ah")
                        lastConsonant = mapped
                    } else {
                        if pendingConsonantVowel {
                            pendingConsonantVowel = false
                        }
                        out.unicodeScalars.append(s)
                        lastConsonant = ""
                    }
                }
                idx += 1
            }

            if out.hasPrefix("'") && out.count > 1 {
                out.removeFirst()
            }
            return out
        }

        let tokens = text.components(separatedBy: .whitespaces)
        var resultTokens: [String] = []
        resultTokens.reserveCapacity(tokens.count)
        let punct = CharacterSet.punctuationCharacters.union(.symbols)

        for tok in tokens where !tok.isEmpty {
            if let lead = tok.rangeOfCharacter(from: punct.inverted) {
                let prefix = String(tok[..<lead.lowerBound])
                let rest = String(tok[lead.lowerBound...])
                let core: String
                let suffix: String
                if let trail = rest.rangeOfCharacter(from: punct.inverted, options: .backwards) {
                    core = String(rest[..<trail.upperBound])
                    suffix = String(rest[trail.upperBound...])
                } else {
                    core = rest
                    suffix = ""
                }
                let converted = core.unicodeScalars.contains(where: { isArabicLetter($0) }) ? romanizeArabicWord(core) : core
                resultTokens.append(prefix + converted + suffix)
            } else {
                resultTokens.append(tok)
            }
        }

        var joined = resultTokens.joined(separator: " ")
        while joined.contains("  ") {
            joined = joined.replacingOccurrences(of: "  ", with: " ")
        }
        joined = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = joined.first, first.isLowercase {
            joined = String(first).uppercased() + joined.dropFirst()
        }
        return joined.isEmpty ? text : joined
    }
}
