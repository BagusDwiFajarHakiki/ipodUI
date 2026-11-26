import Foundation
import UIKit
import MediaPlayer

struct IPodStreamingCatalogItem: Codable {
    let id: String?
    let title: String
    let artist: String
    let album: String?
    let genre: String?
    let streamURL: String?
    let audioURL: String?
    let url: String?
    let artworkURL: String?
    let duration: TimeInterval?
}

struct IPodStreamingFeedResponse: Codable {
    let tracks: [IPodStreamingCatalogItem]?
    let results: [IPodStreamingCatalogItem]?
}

final class IPodStreamingLibrary {
    static let shared = IPodStreamingLibrary()
    static let pageSize: Int = 50

    private(set) var allStreamingTracks: [IPodTrack] = []
    private var artworkCache: [String: UIImage] = [:]
    private let feedURLString = ProcessInfo.processInfo.environment["IPOD_STREAM_FEED_URL"]
        ?? "https://itunes.apple.com/search?term=indie+lofi+electronic&media=music&entity=song&limit=100"

    private init() {
        loadFallbackRealTracks()
        fetchRemoteStreamingTracks { _ in }
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
        fetchRemoteStreamingTracks { [weak self] success in
            if !success {
                self?.loadFallbackRealTracks(reshuffle: true)
            }
            completion(true)
        }
    }

    private func fetchRemoteStreamingTracks(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: feedURLString) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let rawItems: [IPodStreamingCatalogItem]
            if let wrapper = try? JSONDecoder().decode(IPodStreamingFeedResponse.self, from: data) {
                rawItems = wrapper.tracks ?? wrapper.results ?? []
            } else if let direct = try? JSONDecoder().decode([IPodStreamingCatalogItem].self, from: data) {
                rawItems = direct
            } else {
                rawItems = []
            }

            let parsed: [IPodTrack] = rawItems.enumerated().compactMap { idx, item in
                let linkStr = item.streamURL ?? item.audioURL ?? item.url ?? ""
                guard let audioURL = URL(string: linkStr), !linkStr.isEmpty else { return nil }
                let cleanTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanArtist = item.artist.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanTitle.isEmpty, !cleanArtist.isEmpty else { return nil }

                let albumName = (item.album?.isEmpty == false) ? item.album! : "Streaming Single"
                let genreName = (item.genre?.isEmpty == false) ? item.genre! : "Stream"
                let dur = (item.duration ?? 0) > 0 ? (item.duration ?? 180) : 180
                let thumb = self.makeLowResArtwork(title: cleanTitle, artist: cleanArtist, tag: genreName)

                return self.makeTrack(
                    id: item.id ?? "stream_api_\(idx)_\(cleanTitle)",
                    title: cleanTitle,
                    artist: cleanArtist,
                    album: albumName,
                    duration: dur,
                    assetURL: audioURL,
                    artworkImage: thumb
                )
            }

            DispatchQueue.main.async {
                if !parsed.isEmpty {
                    self.allStreamingTracks = Array(parsed.prefix(150))
                    completion(true)
                } else {
                    completion(false)
                }
            }
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

    private func loadFallbackRealTracks(reshuffle: Bool = false) {
        let catalog: [(title: String, artist: String, album: String, tag: String, duration: TimeInterval, url: String)] = [
            ("Hati-Hati di Jalan", "Tulus", "Manusia", "Pop", 262, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"),
            ("Monokrom", "Tulus", "Monokrom", "Pop", 213, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"),
            ("Bertaut", "Nadin Amizah", "Selamat Ulang Tahun", "Indie", 295, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3"),
            ("Sorai", "Nadin Amizah", "Kalah Bertaruh", "Indie", 244, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3"),
            ("Komang", "Raim Laode", "Komang", "Acoustic", 222, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3"),
            ("Sial", "Mahalini", "Fabula", "Ballad", 240, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3"),
            ("Rewrite The Stars", "Anne-Marie & James Arthur", "The Greatest Showman", "Pop", 218, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3"),
            ("Shape of You", "Ed Sheeran", "Divide", "Pop", 233, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3"),
            ("Blinding Lights", "The Weeknd", "After Hours", "Synth", 200, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3"),
            ("As It Was", "Harry Styles", "Harry's House", "Pop", 167, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3"),
            ("Lathi", "Weird Genius ft. Sara Fajira", "Lathi", "Electronic", 184, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3"),
            ("Runtuh", "Feby Putri ft. Fiersa Besari", "Riuh", "Folk", 252, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3"),
            ("Cukup", "Ziva Magnolya", "Magnolya", "Soul", 241, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3"),
            ("Glimpse of Us", "Joji", "SMITHEREENS", "R&B", 233, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3"),
            ("Snooze", "SZA", "SOS", "R&B", 201, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3"),
            ("Cruel Summer", "Taylor Swift", "Lover", "Pop", 178, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3"),
            ("About You", "The 1975", "Being Funny", "Alt", 326, "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-17.mp3")
        ]

        var built: [IPodTrack] = []
        for idx in 0..<100 {
            let item = catalog[idx % catalog.count]
            let variant = idx / catalog.count
            let title = variant == 0 ? item.title : "\(item.title) (Live)"
            let art = makeLowResArtwork(title: title, artist: item.artist, tag: item.tag)
            let track = makeTrack(
                id: "stream_real_\(idx)_\(item.title)",
                title: title,
                artist: item.artist,
                album: item.album,
                duration: item.duration,
                assetURL: URL(string: item.url),
                artworkImage: art
            )
            built.append(track)
        }

        allStreamingTracks = reshuffle ? built.shuffled() : built
    }

    // Resolusi rendah (96x96) agar cepat di-load dan hemat memori di iPhone 5s
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