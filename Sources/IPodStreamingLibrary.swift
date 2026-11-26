import Foundation
import UIKit
import MediaPlayer

enum IPodStreamResolutionResult {
    case playable(URL)
    case failed(reason: String)
}

private struct ArchiveSearchResponse: Codable {
    let response: ArchiveResponseBody
}

private struct ArchiveResponseBody: Codable {
    let docs: [ArchiveDocItem]
}

private struct ArchiveDocItem: Codable {
    let identifier: String
    let title: String?
    let creator: ArchiveFlexibleString?
    let collection: ArchiveFlexibleString?
}

private enum ArchiveFlexibleString: Codable {
    case single(String)
    case multiple([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .single(str)
        } else if let arr = try? container.decode([String].self) {
            self = .multiple(arr)
        } else {
            self = .single("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let str):
            try container.encode(str)
        case .multiple(let arr):
            try container.encode(arr)
        }
    }

    var primaryValue: String {
        switch self {
        case .single(let str):
            return str
        case .multiple(let arr):
            return arr.first ?? ""
        }
    }
}

private struct ArchiveMetadataResponse: Codable {
    let files: [ArchiveFileItem]?
}

private struct ArchiveFileItem: Codable {
    let name: String?
    let format: String?
    let length: String?
}

final class IPodStreamingLibrary {
    static let shared = IPodStreamingLibrary()
    static let pageSize: Int = 50

    private(set) var allStreamingTracks: [IPodTrack] = []
    private var identifierByTrackId: [String: String] = [:]
    private var resolvedAudioURLCache: [String: URL] = [:]
    private var artworkCache: [String: UIImage] = [:]

    private let searchQueries = [
        "mediatype:audio AND (format:MP3 OR format:VBR\\ MP3)",
        "mediatype:audio AND collection:etree",
        "mediatype:audio AND collection:netlabels",
        "mediatype:audio AND subject:electronic",
        "mediatype:audio AND subject:ambient"
    ]
    private var queryIndex: Int = 0

    // Fallback stream audio penuh jika metadata item Archive.org belum memuat file audio langsung
    private let fallbackFullAudioURLs: [String] = [
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3"
    ]

    private init() {
        fetchFullTracksFromArchive(reshuffle: false) { _ in }
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

    func defaultFallbackURL(for trackId: String) -> URL? {
        let idx = abs(trackId.hashValue) % fallbackFullAudioURLs.count
        return URL(string: fallbackFullAudioURLs[idx])
    }

    func refreshTracks(completion: @escaping (Bool) -> Void) {
        fetchFullTracksFromArchive(reshuffle: true, completion: completion)
    }

    func invalidateCachedURL(for track: IPodTrack) {
        resolvedAudioURLCache.removeValue(forKey: track.id)
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
        if !forceRefresh, let cached = resolvedAudioURLCache[track.id] {
            completion(.playable(cached))
            return
        }

        let backupURL = track.assetURL ?? defaultFallbackURL(for: track.id)

        guard let identifier = identifierByTrackId[track.id], !identifier.isEmpty else {
            if let bURL = backupURL {
                completion(.playable(bURL))
            } else {
                completion(.failed(reason: "Identifier audio kosong"))
            }
            return
        }

        let encodedId = identifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? identifier
        guard let metaURL = URL(string: "https://archive.org/metadata/\(encodedId)") else {
            if let bURL = backupURL {
                completion(.playable(bURL))
            } else {
                completion(.failed(reason: "URL metadata tidak valid"))
            }
            return
        }

        var request = URLRequest(url: metaURL)
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard error == nil, let data = data, status == 200,
                  let meta = try? JSONDecoder().decode(ArchiveMetadataResponse.self, from: data),
                  let files = meta.files else {
                DispatchQueue.main.async {
                    if let bURL = backupURL {
                        completion(.playable(bURL))
                    } else {
                        completion(.failed(reason: "Metadata HTTP \(status)"))
                    }
                }
                return
            }

            let audioCandidate = files.first { file in
                guard let name = file.name?.lowercased(), !name.isEmpty else { return false }
                return name.hasSuffix(".mp3") || name.hasSuffix(".m4a") || name.hasSuffix(".ogg")
            }

            guard let fileName = audioCandidate?.name,
                  let encodedFile = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let audioURL = URL(string: "https://archive.org/download/\(encodedId)/\(encodedFile)") else {
                DispatchQueue.main.async {
                    if let bURL = backupURL {
                        completion(.playable(bURL))
                    } else {
                        completion(.failed(reason: "File audio penuh tidak ditemukan"))
                    }
                }
                return
            }

            self.resolvedAudioURLCache[track.id] = audioURL
            DispatchQueue.main.async {
                completion(.playable(audioURL))
            }
        }.resume()
    }

    private func fetchFullTracksFromArchive(reshuffle: Bool, completion: @escaping (Bool) -> Void) {
        let q = searchQueries[queryIndex % searchQueries.count]
        queryIndex += 1

        guard var comps = URLComponents(string: "https://archive.org/advancedsearch.php") else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        comps.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "fl[]", value: "identifier"),
            URLQueryItem(name: "fl[]", value: "title"),
            URLQueryItem(name: "fl[]", value: "creator"),
            URLQueryItem(name: "fl[]", value: "collection"),
            URLQueryItem(name: "rows", value: "50"),
            URLQueryItem(name: "page", value: String((queryIndex % 5) + 1)),
            URLQueryItem(name: "output", value: "json")
        ]

        guard let url = comps.url else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard error == nil, let data = data, code == 200,
                  let decoded = try? JSONDecoder().decode(ArchiveSearchResponse.self, from: data) else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            var built: [IPodTrack] = []
            var idMap: [String: String] = [:]

            for (idx, doc) in decoded.response.docs.enumerated() {
                let rawTitle = (doc.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanTitle = rawTitle.isEmpty ? doc.identifier : rawTitle
                let creatorStr = doc.creator?.primaryValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let artist = creatorStr.isEmpty ? "Archive Artist" : creatorStr
                let albumStr = doc.collection?.primaryValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let album = albumStr.isEmpty ? "Full Audio" : albumStr

                let trackId = "stream_\(doc.identifier)_\(idx)"
                let art = self.placeholderArtwork(seed: doc.identifier)
                let initialURL = self.defaultFallbackURL(for: trackId)
                let track = self.makeTrack(
                    id: trackId,
                    title: cleanTitle,
                    artist: artist,
                    album: album,
                    duration: 210,
                    assetURL: initialURL,
                    artworkImage: art
                )
                built.append(track)
                idMap[trackId] = doc.identifier
            }

            DispatchQueue.main.async {
                self.identifierByTrackId = idMap
                self.allStreamingTracks = reshuffle ? built.shuffled() : built
                self.loadLowResThumbnailsAsync(for: self.allStreamingTracks)
                completion(!built.isEmpty)
            }
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
            guard let identifier = identifierByTrackId[track.id],
                  let encodedId = identifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://archive.org/services/img/\(encodedId)") else { continue }
            if let cached = artworkCache[identifier] {
                replaceTrackArtwork(at: idx, expectedId: track.id, image: cached)
                continue
            }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let rawImg = UIImage(data: data) else { return }
                let lowRes = self.downsampleImage(rawImg, targetSide: 96)
                self.artworkCache[identifier] = lowRes
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
        if let cached = artworkCache["ph_\(seed)"] {
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
            artworkCache["ph_\(seed)"] = img
        }
        return img
    }
}