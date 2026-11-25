import UIKit
import AVFoundation
import MediaPlayer

enum IPodMenuNode {
    case root
    case music
    case playlists
    case playlistTracks(IPodPlaylistGroup)
    case artists
    case artistTracks(String, [IPodTrack])
    case albums
    case albumTracks(String, [IPodTrack])
    case allSongs
    case settings
}

class IPodViewController: UIViewController, ClickWheelDelegate {
    private let bodyGradient = CAGradientLayer()
    private let screenView = IPodScreenView()
    private let clickWheel = ClickWheelView()

    private var menuStack: [(node: IPodMenuNode, selectedIndex: Int)] = [(.root, 0)]
    private var isNowPlayingActive = false

    private var player: AVPlayer?
    private var playbackTimer: Timer?
    private var endObserver: Any?
    private var currentQueue: [IPodTrack] = []
    private var currentTrackIndex: Int = 0
    private var isPlaying = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBodyAndLayout()
        setupAudioSession()
        setupRemoteCommands()

        clickWheel.delegate = self
        renderTopMenu(restoreIndex: 0)

        IPodMusicLibrary.shared.requestAccessAndLoad { [weak self] in
            self?.renderTopMenu(restoreIndex: 0)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bodyGradient.frame = view.bounds
    }

    private func setupBodyAndLayout() {
        bodyGradient.colors = [
            UIColor(white: 0.88, alpha: 1.0).cgColor,
            UIColor(white: 0.76, alpha: 1.0).cgColor
        ]
        view.layer.insertSublayer(bodyGradient, at: 0)

        screenView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(screenView)

        clickWheel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clickWheel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            screenView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 14),
            screenView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            screenView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            screenView.heightAnchor.constraint(equalTo: screenView.widthAnchor, multiplier: 0.76),

            clickWheel.topAnchor.constraint(equalTo: screenView.bottomAnchor, constant: 24),
            clickWheel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clickWheel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.72),
            clickWheel.heightAnchor.constraint(equalTo: clickWheel.widthAnchor)
        ])
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - Menu Navigation Engine
    private func rows(for node: IPodMenuNode) -> (title: String, items: [IPodMenuRow]) {
        switch node {
        case .root:
            var items = [
                IPodMenuRow(title: "Music", hasSubmenu: true),
                IPodMenuRow(title: "Shuffle Songs", hasSubmenu: false),
                IPodMenuRow(title: "Settings", hasSubmenu: true)
            ]
            if !currentQueue.isEmpty {
                items.append(IPodMenuRow(title: "Now Playing", hasSubmenu: true))
            }
            return ("SepiaPod", items)

        case .music:
            return ("Music", [
                IPodMenuRow(title: "Playlists", hasSubmenu: true),
                IPodMenuRow(title: "Artists", hasSubmenu: true),
                IPodMenuRow(title: "Albums", hasSubmenu: true),
                IPodMenuRow(title: "Songs", hasSubmenu: true)
            ])

        case .playlists:
            let pls = IPodMusicLibrary.shared.playlists
            if pls.isEmpty {
                return ("Playlists", [IPodMenuRow(title: "Tidak ada playlist", hasSubmenu: false)])
            }
            return ("Playlists", pls.map { IPodMenuRow(title: "\($0.name) (\($0.tracks.count))", hasSubmenu: true) })

        case .playlistTracks(let group):
            return (group.name, group.tracks.map { IPodMenuRow(title: $0.title, hasSubmenu: false) })

        case .artists:
            let keys = IPodMusicLibrary.shared.artists.keys.sorted()
            if keys.isEmpty {
                return ("Artists", [IPodMenuRow(title: "Pustaka kosong", hasSubmenu: false)])
            }
            return ("Artists", keys.map { IPodMenuRow(title: $0, hasSubmenu: true) })

        case .artistTracks(let artist, let tracks):
            return (artist, tracks.map { IPodMenuRow(title: $0.title, hasSubmenu: false) })

        case .albums:
            let keys = IPodMusicLibrary.shared.albums.keys.sorted()
            if keys.isEmpty {
                return ("Albums", [IPodMenuRow(title: "Pustaka kosong", hasSubmenu: false)])
            }
            return ("Albums", keys.map { IPodMenuRow(title: $0, hasSubmenu: true) })

        case .albumTracks(let album, let tracks):
            return (album, tracks.map { IPodMenuRow(title: $0.title, hasSubmenu: false) })

        case .allSongs:
            let songs = IPodMusicLibrary.shared.allTracks
            if songs.isEmpty {
                return ("Songs", [IPodMenuRow(title: "Sinkronkan lagu ke Music/Documents", hasSubmenu: false)])
            }
            return ("Songs", songs.map { IPodMenuRow(title: $0.title, hasSubmenu: false) })

        case .settings:
            let themeLabel = screenView.theme == .sepiaPod ? "Theme: SepiaPod" : "Theme: Classic Blue"
            return ("Settings", [
                IPodMenuRow(title: themeLabel, hasSubmenu: false),
                IPodMenuRow(title: "Reload Music Library", hasSubmenu: false)
            ])
        }
    }

    private func renderTopMenu(restoreIndex: Int) {
        guard let top = menuStack.last else { return }
        isNowPlayingActive = false
        let content = rows(for: top.node)
        screenView.showMenu(title: content.title, items: content.items, selectedIndex: restoreIndex)
    }

    private func pushMenu(_ node: IPodMenuNode) {
        if !menuStack.isEmpty {
            menuStack[menuStack.count - 1].selectedIndex = screenView.selectedIndex
        }
        menuStack.append((node, 0))
        renderTopMenu(restoreIndex: 0)
    }

    // MARK: - ClickWheelDelegate
    func clickWheelDidScroll(steps: Int) {
        if isNowPlayingActive {
            // Putar roda saat di Now Playing untuk mengatur volume sistem
            if let slider = MPVolumeView().subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = min(max(0, slider.value + Float(steps) * 0.06), 1.0)
            }
            return
        }
        screenView.moveSelection(by: steps)
    }

    func clickWheelDidPressMenu() {
        if isNowPlayingActive {
            let idx = menuStack.last?.selectedIndex ?? 0
            renderTopMenu(restoreIndex: idx)
            return
        }
        if menuStack.count > 1 {
            menuStack.removeLast()
            let prevIndex = menuStack.last?.selectedIndex ?? 0
            renderTopMenu(restoreIndex: prevIndex)
        }
    }

    func clickWheelDidPressSelect() {
        if isNowPlayingActive { return }
        guard let top = menuStack.last else { return }
        let idx = screenView.selectedIndex

        switch top.node {
        case .root:
            if idx == 0 {
                pushMenu(.music)
            } else if idx == 1 {
                let all = IPodMusicLibrary.shared.allTracks
                if !all.isEmpty {
                    startQueue(tracks: all.shuffled(), at: 0)
                }
            } else if idx == 2 {
                pushMenu(.settings)
            } else if idx == 3, !currentQueue.isEmpty {
                openNowPlayingScreen()
            }

        case .music:
            switch idx {
            case 0: pushMenu(.playlists)
            case 1: pushMenu(.artists)
            case 2: pushMenu(.albums)
            case 3: pushMenu(.allSongs)
            default: break
            }

        case .playlists:
            let pls = IPodMusicLibrary.shared.playlists
            if pls.indices.contains(idx) {
                pushMenu(.playlistTracks(pls[idx]))
            }

        case .playlistTracks(let group):
            if group.tracks.indices.contains(idx) {
                startQueue(tracks: group.tracks, at: idx)
            }

        case .artists:
            let keys = IPodMusicLibrary.shared.artists.keys.sorted()
            if keys.indices.contains(idx) {
                let artist = keys[idx]
                let tracks = IPodMusicLibrary.shared.artists[artist] ?? []
                pushMenu(.artistTracks(artist, tracks))
            }

        case .artistTracks(_, let tracks):
            if tracks.indices.contains(idx) {
                startQueue(tracks: tracks, at: idx)
            }

        case .albums:
            let keys = IPodMusicLibrary.shared.albums.keys.sorted()
            if keys.indices.contains(idx) {
                let album = keys[idx]
                let tracks = IPodMusicLibrary.shared.albums[album] ?? []
                pushMenu(.albumTracks(album, tracks))
            }

        case .albumTracks(_, let tracks):
            if tracks.indices.contains(idx) {
                startQueue(tracks: tracks, at: idx)
            }

        case .allSongs:
            let songs = IPodMusicLibrary.shared.allTracks
            if songs.indices.contains(idx) {
                startQueue(tracks: songs, at: idx)
            }

        case .settings:
            if idx == 0 {
                screenView.theme = (screenView.theme == .sepiaPod) ? .classicBlue : .sepiaPod
                renderTopMenu(restoreIndex: 0)
            } else if idx == 1 {
                IPodMusicLibrary.shared.reloadAllSources()
                renderTopMenu(restoreIndex: 1)
            }
        }
    }

    func clickWheelDidPressPlayPause() {
        togglePlayPause()
    }

    func clickWheelDidPressNext() {
        playNextTrack()
    }

    func clickWheelDidPressPrevious() {
        playPreviousTrack()
    }

    // MARK: - Native AVPlayer Audio Engine
    private func startQueue(tracks: [IPodTrack], at index: Int) {
        guard tracks.indices.contains(index) else { return }
        if !menuStack.isEmpty {
            menuStack[menuStack.count - 1].selectedIndex = index
        }
        currentQueue = tracks
        currentTrackIndex = index
        playTrack(at: index)
        openNowPlayingScreen()
    }

    private func openNowPlayingScreen() {
        guard currentQueue.indices.contains(currentTrackIndex) else { return }
        isNowPlayingActive = true
        let track = currentQueue[currentTrackIndex]
        screenView.showNowPlaying(track: track, index: currentTrackIndex, total: currentQueue.count)
    }

    private func playTrack(at index: Int) {
        guard currentQueue.indices.contains(index) else { return }
        let track = currentQueue[index]
        guard let url = track.assetURL else { return }

        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        isPlaying = true
        screenView.updatePlayState(isPlaying: true)

        if isNowPlayingActive {
            screenView.showNowPlaying(track: track, index: index, total: currentQueue.count)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.playNextTrack()
        }

        startProgressTimer()
        updateNowPlayingInfo(track: track, elapsed: 0)
    }

    private func togglePlayPause() {
        guard let player = player, currentQueue.indices.contains(currentTrackIndex) else {
            let all = IPodMusicLibrary.shared.allTracks
            if !all.isEmpty { startQueue(tracks: all, at: 0) }
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        screenView.updatePlayState(isPlaying: isPlaying)
        let track = currentQueue[currentTrackIndex]
        let elapsed = CMTimeGetSeconds(player.currentTime())
        updateNowPlayingInfo(track: track, elapsed: elapsed.isFinite ? elapsed : 0)
    }

    private func playNextTrack() {
        guard !currentQueue.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex + 1) % currentQueue.count
        playTrack(at: currentTrackIndex)
    }

    private func playPreviousTrack() {
        guard !currentQueue.isEmpty else { return }
        if let player = player, CMTimeGetSeconds(player.currentTime()) > 4.0 {
            player.seek(to: .zero)
            return
        }
        currentTrackIndex = (currentTrackIndex - 1 + currentQueue.count) % currentQueue.count
        playTrack(at: currentTrackIndex)
    }

    private func startProgressTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player,
                  self.currentQueue.indices.contains(self.currentTrackIndex) else { return }
            let track = self.currentQueue[self.currentTrackIndex]
            let elapsed = CMTimeGetSeconds(player.currentTime())
            let itemDur = player.currentItem.map { CMTimeGetSeconds($0.duration) } ?? track.duration
            let validDur = (itemDur.isFinite && itemDur > 0) ? itemDur : track.duration
            if elapsed.isFinite {
                self.screenView.updateProgress(elapsed: elapsed, duration: validDur)
                self.updateNowPlayingInfo(track: track, elapsed: elapsed)
            }
        }
    }

    private func updateNowPlayingInfo(track: IPodTrack, elapsed: TimeInterval) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let art = track.artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            if self?.isPlaying == false { self?.togglePlayPause() }
            return .success
        }
        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true { self?.togglePlayPause() }
            return .success
        }
        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        cc.nextTrackCommand.isEnabled = true
        cc.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNextTrack()
            return .success
        }
        cc.previousTrackCommand.isEnabled = true
        cc.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPreviousTrack()
            return .success
        }
    }
}