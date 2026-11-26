import Foundation
import UIKit
import MediaPlayer

enum IPodStreamResolutionResult {
    case playable(URL)
    case failed(reason: String)
}

private struct ITunesSearchResponse: Codable {
    let resultCount: Int?
    let results: [ITunesSongItem]
}

private struct ITunesSongItem: Codable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let previewUrl: String?
    let artworkUrl100: String?
    let trackTimeMillis: Int?
}

final class IPodStreamingLibrary {
    static let shared = IPodStreamingLibrary()
    static let pageSize: Int = 50

    private(set) var allStreamingTracks: [IPodTrack] = []
    private var streamURLByTrackId: [String: URL] = [:]
    private var artworkURLByTrackId: [String: String] = [:]
    private var artworkCache: [String: UIImage] = [:]

    private let searchTerms = [
        "tulus",
        "nadin amizah",
        "arctic monkeys",
        "daft punk",
        "lofi hip hop"
    ]
    private var termCursor: Int = 0

    private init() {
        fetchTracksFromITunes(reshuffle: false) { _ in }
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
        fetchTracksFromITunes(reshuffle: true, completion: completion)
    }

    func invalidateCachedURL(for track: IPodTrack) {
        if let url = streamURLByTrackId[track.id] {
            streamURLByTrackId[track.id] = url
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
        if let url = streamURLByTrackId[track.id] ?? track.assetURL {
            completion(.playable(url))
            return
        }
        completion(.failed(reason: "Preview URL tidak tersedia"))
    }

    private func fetchTracksFromITunes(reshuffle: Bool, completion: @escaping (Bool) -> Void) {
        let term = searchTerms[termCursor % searchTerms.count]
        termCursor += 1

        guard var comps = URLComponents(string: "https://itunes.apple.com/search") else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        comps.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "50")
        ]

        guard let url = comps.url else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let err = error {
                DispatchQueue.main.async {
                    completion(false)
                }
                print("iTunes API error: \(err.localizedDescription)")
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data, status == 200,
                  let decoded = try? JSONDecoder().decode(ITunesSearchResponse.self, from: data) else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            var builtTracks: [IPodTrack] = []
            var urlMap: [String: URL] = [:]
            var artMap: [String: String] = [:]

            for (idx, item) in decoded.results.enumerated() {
                guard let title = item.trackName, !title.isEmpty,
                      let artist = item.artistName, !artist.isEmpty,
                      let previewStr = item.previewUrl,
                      let previewURL = URL(string: previewStr) else {
                    continue
                }

                let rawId = item.trackId.map { String($0) } ?? "\(idx)_\(title.hashValue)"
                let uniqueId = "stream_\(rawId)_\(idx)"
                let album = (item.collectionName?.isEmpty == false) ? item.collectionName! : "Single"
                let durationSec: TimeInterval = {
                    if let ms = item.trackTimeMillis, ms > 0 {
                        return TimeInterval(ms) / 1000.0
                    }
                    return 30.0
                }()

                let art = self.placeholderArtwork(seed: uniqueId)
                let track = self.makeTrack(
                    id: uniqueId,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: durationSec,
                    assetURL: previewURL,
                    artworkImage: art
                )

                builtTracks.append(track)
                urlMap[uniqueId] = previewURL
                if let artUrl = item.artworkUrl100, !artUrl.isEmpty {
                    artMap[uniqueId] = artUrl
                }
            }

            DispatchQueue.main.async {
                self.streamURLByTrackId = urlMap
                self.artworkURLByTrackId = artMap
                self.allStreamingTracks = reshuffle ? builtTracks.shuffled() : builtTracks
                self.loadLowResThumbnailsAsync(for: self.allStreamingTracks)
                completion(!builtTracks.isEmpty)
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
            guard let artStr = artworkURLByTrackId[track.id],
                  let url = URL(string: artStr) else { continue }
            if let cached = artworkCache[artStr] {
                replaceTrackArtwork(at: idx, expectedId: track.id, image: cached)
                continue
            }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let rawImg = UIImage(data: data) else { return }
                let lowRes = self.downsampleImage(rawImg, targetSide: 96)
                self.artworkCache[artStr] = lowRes
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