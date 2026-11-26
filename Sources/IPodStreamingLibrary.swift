import Foundation
import UIKit

struct IPodStreamingCatalogItem: Codable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let genre: String
    let streamURL: String
    let artworkURL: String?
    let duration: TimeInterval?
}

final class IPodStreamingLibrary {
    static let shared = IPodStreamingLibrary()
    static let pageSize: Int = 50

    private(set) var allStreamingTracks: [IPodTrack] = []
    private var artworkCache: [String: UIImage] = [:]
    private let remoteFeedURLString = ProcessInfo.processInfo.environment["IPOD_STREAM_FEED_URL"] ?? ""

    private init() {
        loadSeedTracks()
    }

    private func makeTrack(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        assetURL: URL?,
        artworkImage: UIImage?
    ) -> IPodTrack {
        return IPodTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            assetURL: assetURL,
            artworkImage: artworkImage
        )
    }

    func refreshTracks(completion: @escaping (Bool) -> Void) {
        if let url = URL(string: remoteFeedURLString), !remoteFeedURLString.isEmpty {
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let self = self else { return }
                if let data = data, error == nil,
                   let decoded = try? JSONDecoder().decode([IPodStreamingCatalogItem].self, from: data),
                   !decoded.isEmpty {
                    let mapped = decoded.compactMap { item -> IPodTrack? in
                        guard let audioURL = URL(string: item.streamURL) else { return nil }
                        let art = self.makeArtwork(title: item.title, artist: item.artist, genre: item.genre)
                        return self.makeTrack(
                            title: item.title,
                            artist: item.artist,
                            album: item.album,
                            duration: item.duration ?? 180,
                            assetURL: audioURL,
                            artworkImage: art
                        )
                    }
                    if !mapped.isEmpty {
                        DispatchQueue.main.async {
                            self.allStreamingTracks = mapped
                            completion(true)
                        }
                        return
                    }
                }
                DispatchQueue.main.async {
                    self.loadSeedTracks()
                    completion(true)
                }
            }
            task.resume()
            return
        }

        loadSeedTracks(reshuffle: true)
        completion(true)
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

    private func loadSeedTracks(reshuffle: Bool = false) {
        let presets: [(title: String, artist: String, album: String, genre: String, duration: TimeInterval, url: String)] = [
            ("Midnight Drive", "Kaito", "Night Signals", "Synthwave", 214, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"),
            ("Afterglow Echoes", "Kaito", "Night Signals", "Synthwave", 198, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"),
            ("Neon Boulevard", "Sora", "City Lights", "Electronic", 226, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3"),
            ("Rain on Glass", "Mina", "Quiet Hours", "Lo-Fi", 184, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3"),
            ("Velvet Horizon", "Sora", "City Lights", "Electronic", 205, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3"),
            ("Coffee & Tape", "Mina", "Quiet Hours", "Lo-Fi", 172, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3"),
            ("Solaris Pulse", "Renji", "Orbit", "Ambient", 241, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3"),
            ("Blue Harbor", "Hana", "Coastal Wind", "Acoustic", 192, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3"),
            ("Golden Dusk", "Hana", "Coastal Wind", "Acoustic", 209, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3"),
            ("Starlight Drift", "Renji", "Orbit", "Ambient", 233, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3")
        ]

        var built: [IPodTrack] = []
        let targetCount = 120
        for idx in 0..<targetCount {
            let base = presets[idx % presets.count]
            let cycle = idx / presets.count
            let title = cycle == 0 ? base.title : "\(base.title) \(cycle + 1)"
            let art = makeArtwork(title: title, artist: base.artist, genre: base.genre)
            let track = makeTrack(
                title: title,
                artist: base.artist,
                album: base.album,
                duration: base.duration,
                assetURL: URL(string: base.url),
                artworkImage: art
            )
            built.append(track)
        }

        allStreamingTracks = reshuffle ? built.shuffled() : built
    }

    private func makeArtwork(title: String, artist: String, genre: String) -> UIImage? {
        let key = "\(artist)_\(genre)"
        if let cached = artworkCache[key] {
            return cached
        }

        let hash = abs(key.hashValue)
        let hue = CGFloat(hash % 360) / 360.0
        let bgColor = UIColor(hue: hue, saturation: 0.58, brightness: 0.34, alpha: 1.0)
        let accentColor = UIColor(hue: fmod(hue + 0.14, 1.0), saturation: 0.72, brightness: 0.78, alpha: 1.0)

        let size = CGSize(width: 180, height: 180)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }

        bgColor.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        accentColor.withAlphaComponent(0.28).setFill()
        UIBezierPath(ovalIn: CGRect(x: -20, y: -20, width: 130, height: 130)).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let glyph = "♪"
        let gSize = glyph.size(withAttributes: attrs)
        glyph.draw(
            at: CGPoint(x: (size.width - gSize.width) / 2.0, y: (size.height - gSize.height) / 2.0 - 8),
            withAttributes: attrs
        )

        let tagAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let tag = genre.uppercased()
        let tSize = tag.size(withAttributes: tagAttrs)
        tag.draw(
            at: CGPoint(x: (size.width - tSize.width) / 2.0, y: size.height - tSize.height - 14),
            withAttributes: tagAttrs
        )

        let img = UIGraphicsGetImageFromCurrentImageContext()
        if let img = img {
            artworkCache[key] = img
        }
        return img
    }
}