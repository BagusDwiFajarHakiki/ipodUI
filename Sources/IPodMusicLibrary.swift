import UIKit
import MediaPlayer
import AVFoundation

struct IPodTrack {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let assetURL: URL?
    let mediaItem: MPMediaItem?
    let artworkImage: UIImage?
}

struct IPodPlaylistGroup {
    let name: String
    let tracks: [IPodTrack]
    let nativePlaylist: MPMediaPlaylist?
}

class IPodMusicLibrary {
    static let shared = IPodMusicLibrary()

    private(set) var allTracks: [IPodTrack] = []
    private(set) var playlists: [IPodPlaylistGroup] = []

    private init() {}

    func requestAccessAndLoad(completion: @escaping () -> Void) {
        MPMediaLibrary.requestAuthorization { [weak self] _ in
            self?.reloadAllSources()
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func reloadAllSources() {
        var collectedTracks: [IPodTrack] = []
        var playlistGroups: [IPodPlaylistGroup] = []

        if MPMediaLibrary.authorizationStatus() == .authorized {
            let songsQuery = MPMediaQuery.songs()
            if let items = songsQuery.items {
                for item in items where item.assetURL != nil {
                    collectedTracks.append(makeTrack(from: item))
                }
            }

            let playlistsQuery = MPMediaQuery.playlists()
            if let collections = playlistsQuery.collections {
                for collection in collections {
                    guard let mediaPlaylist = collection as? MPMediaPlaylist else { continue }
                    let plName = mediaPlaylist.name ?? "Playlist"
                    let plTracks = mediaPlaylist.items.filter { $0.assetURL != nil }.map { makeTrack(from: $0) }
                    playlistGroups.append(IPodPlaylistGroup(name: plName, tracks: plTracks, nativePlaylist: mediaPlaylist))
                }
            }
        }

        let localTracks = scanDocumentsFolder()
        if !localTracks.isEmpty {
            collectedTracks.append(contentsOf: localTracks)
            playlistGroups.insert(IPodPlaylistGroup(name: "File Lokal (Documents)", tracks: localTracks, nativePlaylist: nil), at: 0)
        }

        self.allTracks = sortTracksAlphabetically(collectedTracks)
        self.playlists = playlistGroups
    }

    private func sortTracksAlphabetically(_ tracks: [IPodTrack]) -> [IPodTrack] {
        return tracks.sorted { lhs, rhs in
            let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            let artistOrder = lhs.artist.localizedCaseInsensitiveCompare(rhs.artist)
            if artistOrder != .orderedSame {
                return artistOrder == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    // Membuat playlist baru langsung di aplikasi Music bawaan iOS & menyinkronkan lagu terpilih
    func createNativePlaylist(name: String, tracksToAdd: [IPodTrack], completion: @escaping (Bool) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "iPod Playlist" : trimmed

        guard MPMediaLibrary.authorizationStatus() == .authorized else {
            completion(false)
            return
        }

        let uuid = UUID()
        let metadata = MPMediaPlaylistCreationMetadata(name: finalName)
        metadata.authorDisplayName = "iPod"

        MPMediaLibrary.default().getPlaylist(with: uuid, creationMetadata: metadata) { [weak self] playlist, error in
            guard let self = self, let playlist = playlist, error == nil else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let mediaItems = tracksToAdd.compactMap { $0.mediaItem }
            if !mediaItems.isEmpty {
                playlist.add(mediaItems) { _ in
                    self.reloadAllSources()
                    DispatchQueue.main.async { completion(true) }
                }
            } else {
                self.reloadAllSources()
                DispatchQueue.main.async { completion(true) }
            }
        }
    }

    private func makeTrack(from item: MPMediaItem) -> IPodTrack {
        let title = item.title ?? "Unknown Track"
        let artist = item.artist ?? "Unknown Artist"
        let album = item.albumTitle ?? "Unknown Album"
        let art = item.artwork?.image(at: CGSize(width: 300, height: 300))
        return IPodTrack(
            id: "\(item.persistentID)",
            title: title,
            artist: artist,
            album: album,
            duration: item.playbackDuration,
            assetURL: item.assetURL,
            mediaItem: item,
            artworkImage: art
        )
    }

    private func scanDocumentsFolder() -> [IPodTrack] {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let files = try? FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil) else {
            return []
        }

        let allowedExts: Set<String> = ["mp3", "m4a", "aac", "wav", "flac"]
        var result: [IPodTrack] = []

        for fileURL in files where allowedExts.contains(fileURL.pathExtension.lowercased()) {
            let asset = AVURLAsset(url: fileURL)
            let durationSec = CMTimeGetSeconds(asset.duration)
            var title = fileURL.deletingPathExtension().lastPathComponent
            var artist = "Local Audio"
            var album = "Documents"
            var artwork: UIImage? = nil

            for meta in asset.commonMetadata {
                if meta.commonKey == .commonKeyTitle, let val = meta.stringValue, !val.isEmpty {
                    title = val
                } else if meta.commonKey == .commonKeyArtist, let val = meta.stringValue, !val.isEmpty {
                    artist = val
                } else if meta.commonKey == .commonKeyAlbumName, let val = meta.stringValue, !val.isEmpty {
                    album = val
                } else if meta.commonKey == .commonKeyArtwork, let data = meta.dataValue, let img = UIImage(data: data) {
                    artwork = img
                }
            }

            result.append(IPodTrack(
                id: fileURL.lastPathComponent,
                title: title,
                artist: artist,
                album: album,
                duration: durationSec.isFinite ? durationSec : 0,
                assetURL: fileURL,
                mediaItem: nil,
                artworkImage: artwork
            ))
        }
        return sortTracksAlphabetically(result)
    }
}