import UIKit
import AVFoundation
import MediaPlayer

enum IPodMenuNode {
    case root
    case music
    case playlists
    case playlistTracks(IPodPlaylistGroup)
    case allSongs
    case streamingSongs(pageIndex: Int)
    case settings
}

class IPodViewController: UIViewController, ClickWheelDelegate {
    private let bodyGradient = CAGradientLayer()
    private let ambientGlowImageView = UIImageView()
    private let screenView = IPodScreenView()
    private let clickWheel = ClickWheelView()

    private var menuStack: [(node: IPodMenuNode, selectedIndex: Int)] = [(.root, 0)]
    private var isNowPlayingActive = false
    private var isPlaylistsMenuEnabled: Bool = true
    private var currentGlowColor = UIColor(red: 0.25, green: 0.52, blue: 0.92, alpha: 1.0)
    private var playingTrackArtwork: UIImage?
    private var lastGlowSize: CGSize = .zero

    private var player: AVPlayer?
    private var playbackTimer: Timer?
    private var endObserver: Any?
    private var currentQueue: [IPodTrack] = []
    private var currentTrackIndex: Int = 0
    private var isPlaying = false
    private var isShuffleActive = false

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isPlaylistsMenuEnabled = UserDefaults.standard.object(forKey: "ipod_playlists_enabled") as? Bool ?? true
        setupBodyAndLayout()
        applyThemeToBodyAndWheel()
        setupAudioSession()
        setupRemoteCommands()

        clickWheel.delegate = self

        screenView.onCoverFlowTrackSelected = { [weak self] index in
            guard let self = self else { return }
            if let top = self.menuStack.last, case .streamingSongs(let pageIndex) = top.node {
                let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: pageIndex)
                if pageData.tracks.indices.contains(index) {
                    let chosen = pageData.tracks[index]
                    self.startQueue(
                        tracks: IPodStreamingLibrary.shared.allStreamingTracks,
                        at: 0,
                        selectedTrack: chosen,
                        useRelatedOrder: true
                    )
                }
                return
            }

            let songs = IPodMusicLibrary.shared.allTracks
            if songs.indices.contains(index) {
                self.startQueue(tracks: songs, at: index, useRelatedOrder: false)
            }
        }

        screenView.onSeekRatioChanged = { [weak self] ratio, isFinished in
            self?.seekToRatio(ratio, isFinished: isFinished)
        }

        screenView.onActiveCoverImageChanged = { [weak self] image in
            self?.updateAmbientGlow(from: image)
        }

        screenView.onStreamingRefreshTapped = { [weak self] in
            self?.refreshStreamingList()
        }

        renderTopMenu(restoreIndex: 0)

        IPodMusicLibrary.shared.requestAccessAndLoad { [weak self] in
            self?.renderTopMenu(restoreIndex: 0)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bodyGradient.frame = view.bounds

        let glowSize = ambientGlowImageView.bounds.size
        let screenFrameInGlow = screenView.convert(screenView.bounds, to: ambientGlowImageView)
        if glowSize.width > 0, glowSize.height > 0, screenFrameInGlow.width > 0, glowSize != lastGlowSize {
            lastGlowSize = glowSize
            ambientGlowImageView.image = makeSmoothLcdAmbientImage(
                canvasSize: glowSize,
                lcdRect: screenFrameInGlow
            )
        }
    }

    private func setupBodyAndLayout() {
        view.layer.insertSublayer(bodyGradient, at: 0)

        ambientGlowImageView.contentMode = .scaleToFill
        ambientGlowImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ambientGlowImageView)

        screenView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(screenView)

        clickWheel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clickWheel)

        NSLayoutConstraint.activate([
            screenView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            screenView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            screenView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            screenView.heightAnchor.constraint(equalTo: screenView.widthAnchor, multiplier: 0.80),

            ambientGlowImageView.topAnchor.constraint(equalTo: screenView.topAnchor, constant: -36),
            ambientGlowImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 32),
            ambientGlowImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -36),
            ambientGlowImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 36),

            clickWheel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -42),
            clickWheel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clickWheel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.70),
            clickWheel.heightAnchor.constraint(equalTo: clickWheel.widthAnchor)
        ])
    }

    private func makeSmoothLcdAmbientImage(
        canvasSize: CGSize,
        lcdRect: CGRect
    ) -> UIImage? {
        let w = canvasSize.width
        let h = canvasSize.height
        guard w > 1, h > 1 else { return nil }

        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setFillColor(UIColor.white.withAlphaComponent(0.30).cgColor)
        ctx.fill(CGRect(origin: .zero, size: canvasSize))

        ctx.setBlendMode(.destinationIn)
        let leftSoft = max(0.0, min(0.45, (lcdRect.minX - 24.0) / w))
        let leftFull = max(leftSoft + 0.05, min(0.48, (lcdRect.minX + 6.0) / w))
        let rightFull = max(0.52, min(0.95, (lcdRect.maxX - 6.0) / w))
        let rightSoft = max(rightFull + 0.05, min(1.0, (lcdRect.maxX + 24.0) / w))

        let hColors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.65).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor,
            UIColor.white.withAlphaComponent(0.65).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let hLocations: [CGFloat] = [0.0, leftSoft, leftFull, rightFull, rightSoft, 1.0]

        if let hGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: hColors, locations: hLocations) {
            ctx.drawLinearGradient(
                hGrad,
                start: CGPoint(x: 0, y: h * 0.5),
                end: CGPoint(x: w, y: h * 0.5),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        let topFadeEnd = max(0.04, min(0.28, (lcdRect.minY + 12.0) / h))
        let bottomFadeStart = max(topFadeEnd + 0.10, min(0.88, (lcdRect.maxY + (h - lcdRect.maxY) * 0.55) / h))

        let vColors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.85).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor,
            UIColor.white.withAlphaComponent(0.75).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let vLocations: [CGFloat] = [0.0, topFadeEnd, max(topFadeEnd + 0.04, lcdRect.maxY / h), bottomFadeStart, 1.0]

        if let vGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: vColors, locations: vLocations) {
            ctx.drawLinearGradient(
                vGrad,
                start: CGPoint(x: w * 0.5, y: 0),
                end: CGPoint(x: w * 0.5, y: h),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
        UIGraphicsEndImageContext()
        return img
    }

    private func applyThemeToBodyAndWheel() {
        let theme = screenView.theme
        clickWheel.applyTheme(theme)

        switch theme {
        case .darkPod:
            bodyGradient.colors = [
                UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor,
                UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0).cgColor
            ]
        case .sepiaPod:
            bodyGradient.colors = [
                UIColor(red: 0.90, green: 0.85, blue: 0.76, alpha: 1.0).cgColor,
                UIColor(red: 0.80, green: 0.74, blue: 0.63, alpha: 1.0).cgColor
            ]
        case .classicBlue:
            bodyGradient.colors = [
                UIColor(white: 0.88, alpha: 1.0).cgColor,
                UIColor(white: 0.76, alpha: 1.0).cgColor
            ]
        }

        applyGlowColors(currentGlowColor)
    }

    private func applyGlowColors(_ color: UIColor) {
        let isDark = (screenView.theme == .darkPod)
        ambientGlowImageView.tintColor = color
        ambientGlowImageView.alpha = isDark ? 0.85 : 0.52
    }

    private func updateAmbientGlow(from image: UIImage?) {
        let glowColor = extractDominantColor(from: image) ?? (screenView.theme == .darkPod
            ? UIColor(red: 0.25, green: 0.52, blue: 0.92, alpha: 1.0)
            : UIColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 1.0))

        currentGlowColor = glowColor
        UIView.animate(withDuration: 0.40) {
            self.applyGlowColors(glowColor)
        }
    }

    private func extractDominantColor(from image: UIImage?) -> UIColor? {
        guard let cgImage = image?.cgImage else { return nil }
        let width = 12
        let height = 12
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rTotal: CGFloat = 0
        var gTotal: CGFloat = 0
        var bTotal: CGFloat = 0
        let count = CGFloat(width * height)

        for i in stride(from: 0, to: rawData.count, by: 4) {
            rTotal += CGFloat(rawData[i]) / 255.0
            gTotal += CGFloat(rawData[i + 1]) / 255.0
            bTotal += CGFloat(rawData[i + 2]) / 255.0
        }

        let avgColor = UIColor(red: rTotal / count, green: gTotal / count, blue: bTotal / count, alpha: 1.0)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if avgColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: min(1.0, max(s * 1.35, 0.35)), brightness: min(1.0, max(b * 1.18, 0.58)), alpha: 1.0)
        }
        return avgColor
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

    private var isLightAppIconActive: Bool {
        return UIApplication.shared.alternateIconName == "AppIconLight"
    }

    private func toggleHomeScreenAppIcon() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let nextIconName: String? = isLightAppIconActive ? nil : "AppIconLight"
        UIApplication.shared.setAlternateIconName(nextIconName) { [weak self] _ in
            DispatchQueue.main.async {
                self?.renderTopMenu(restoreIndex: 2)
            }
        }
    }

    private func refreshStreamingList() {
        IPodStreamingLibrary.shared.refreshTracks { [weak self] _ in
            guard let self = self else { return }
            if let top = self.menuStack.last, case .streamingSongs = top.node {
                self.menuStack[self.menuStack.count - 1] = (.streamingSongs(pageIndex: 0), 0)
            }
            self.renderTopMenu(restoreIndex: 0)
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    private func triggerShuffleSongs() {
        let streamingPool = IPodStreamingLibrary.shared.allStreamingTracks
        let offlinePool = IPodMusicLibrary.shared.allTracks
        let source = !streamingPool.isEmpty ? streamingPool : offlinePool
        guard !source.isEmpty else { return }

        var shuffled = source.shuffled()
        if currentQueue.indices.contains(currentTrackIndex), shuffled.count > 1 {
            let activeId = currentQueue[currentTrackIndex].id
            if let first = shuffled.first, first.id == activeId {
                shuffled.swapAt(0, Int.random(in: 1..<shuffled.count))
            }
        }
        let randomStartIdx = Int.random(in: 0..<shuffled.count)
        isShuffleActive = true
        startQueue(tracks: shuffled, at: randomStartIdx, useRelatedOrder: false)
    }

    // MARK: - Menu Navigation Engine
    private func rows(for node: IPodMenuNode) -> (title: String, items: [IPodMenuRow]) {
        switch node {
        case .root:
            return ("iPod", [
                IPodMenuRow(title: "Music", hasSubmenu: true),
                IPodMenuRow(title: "Streaming", hasSubmenu: true),
                IPodMenuRow(title: "Settings", hasSubmenu: true)
            ])

        case .music:
            return ("Music", [
                IPodMenuRow(title: "Playlists", hasSubmenu: true),
                IPodMenuRow(title: "Songs", hasSubmenu: true)
            ])

        case .streamingSongs(let pageIndex):
            let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: pageIndex)
            let header = pageData.totalPages > 1
                ? "Streaming (\(pageData.currentPage + 1)/\(pageData.totalPages))"
                : "Streaming"
            return (header, pageData.tracks.map { IPodMenuRow(title: $0.title, hasSubmenu: false) })

        case .playlists:
            var items = [IPodMenuRow(title: "+ New Playlist...", hasSubmenu: false)]
            let pls = IPodMusicLibrary.shared.playlists
            items.append(contentsOf: pls.map { IPodMenuRow(title: $0.name, hasSubmenu: true, valueBadge: "\($0.tracks.count)") })
            return ("Playlists", items)

        case .playlistTracks(let group):
            if group.tracks.isEmpty {
                return (group.name, [IPodMenuRow(title: "Playlist kosong", hasSubmenu: false)])
            }
            return (group.name, group.tracks.map { IPodMenuRow(title: $0.title, hasSubmenu: false) })

        case .allSongs:
            let songs = IPodMusicLibrary.shared.allTracks
            if songs.isEmpty {
                return ("Songs", [IPodMenuRow(title: "Sinkronkan lagu ke Music/Documents", hasSubmenu: false)])
            }
            return ("Songs", songs.map { IPodMenuRow(title: $0.title, hasSubmenu: false) })

        case .settings:
            return ("Settings", [
                IPodMenuRow(
                    title: "Appearance",
                    hasSubmenu: false,
                    valueBadge: screenView.theme.displayName
                ),
                IPodMenuRow(
                    title: "Playlists Menu",
                    hasSubmenu: false,
                    valueBadge: isPlaylistsMenuEnabled ? "ON" : "OFF",
                    isPositiveToggle: isPlaylistsMenuEnabled
                ),
                IPodMenuRow(
                    title: "App Icon",
                    hasSubmenu: false,
                    valueBadge: isLightAppIconActive ? "Light" : "Dark"
                ),
                IPodMenuRow(
                    title: "Music Library",
                    hasSubmenu: false,
                    valueBadge: "Reload"
                )
            ])
        }
    }

    private func renderTopMenu(restoreIndex: Int, animateFromNowPlaying: Bool = false) {
        guard let top = menuStack.last else { return }
        isNowPlayingActive = false

        if case .allSongs = top.node {
            let songs = IPodMusicLibrary.shared.allTracks
            screenView.showSongsCoverFlow(
                title: "Songs",
                tracks: songs,
                selectedIndex: restoreIndex,
                animateFromNowPlaying: animateFromNowPlaying,
                showStreamingRefresh: false
            )
            return
        }

        if case .streamingSongs(let pageIndex) = top.node {
            let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: pageIndex)
            let header = pageData.totalPages > 1
                ? "Streaming (\(pageData.currentPage + 1)/\(pageData.totalPages))"
                : "Streaming"
            screenView.showSongsCoverFlow(
                title: header,
                tracks: pageData.tracks,
                selectedIndex: restoreIndex,
                animateFromNowPlaying: animateFromNowPlaying,
                showStreamingRefresh: true
            )
            return
        }

        updateAmbientGlow(from: playingTrackArtwork)

        let isSettings = {
            if case .settings = top.node { return true }
            return false
        }()

        let content = rows(for: top.node)
        screenView.showMenu(
            title: content.title,
            items: content.items,
            selectedIndex: restoreIndex,
            isModernSettings: isSettings,
            showStreamingRefresh: false
        )
    }

    private func pushMenu(_ node: IPodMenuNode) {
        if !menuStack.isEmpty {
            menuStack[menuStack.count - 1].selectedIndex = screenView.selectedIndex
        }
        menuStack.append((node, 0))
        renderTopMenu(restoreIndex: 0)
    }

    // MARK: - Buat Playlist Sinkron ke Aplikasi Music Bawaan
    private func presentCreatePlaylistDialog() {
        let alert = UIAlertController(
            title: "New Playlist",
            message: "Masukkan nama playlist baru (sinkron ke aplikasi Music):",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Contoh: Favorit"
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Lanjut Pilih Lagu", style: .default) { [weak self] _ in
            let name = alert.textFields?.first?.text ?? "iPod Playlist"
            self?.presentTrackSelectionForNewPlaylist(playlistName: name)
        })
        alert.addAction(UIAlertAction(title: "Simpan Kosong", style: .default) { [weak self] _ in
            let name = alert.textFields?.first?.text ?? "iPod Playlist"
            IPodMusicLibrary.shared.createNativePlaylist(name: name, tracksToAdd: []) { _ in
                self?.renderTopMenu(restoreIndex: 1)
            }
        })
        alert.addAction(UIAlertAction(title: "Batal", style: .cancel))
        present(alert, animated: true)
    }

    private func presentTrackSelectionForNewPlaylist(playlistName: String) {
        let allSongs = IPodMusicLibrary.shared.allTracks
        guard !allSongs.isEmpty else {
            IPodMusicLibrary.shared.createNativePlaylist(name: playlistName, tracksToAdd: []) { [weak self] _ in
                self?.renderTopMenu(restoreIndex: 1)
            }
            return
        }

        let sheet = UIAlertController(
            title: "Tambah Lagu ke \"\(playlistName)\"",
            message: "Pilih lagu dari pustaka Music untuk dimasukkan:",
            preferredStyle: .actionSheet
        )

        for track in allSongs.prefix(15) {
            sheet.addAction(UIAlertAction(title: "\(track.title) - \(track.artist)", style: .default) { [weak self] _ in
                IPodMusicLibrary.shared.createNativePlaylist(name: playlistName, tracksToAdd: [track]) { _ in
                    self?.renderTopMenu(restoreIndex: 1)
                }
            })
        }

        sheet.addAction(UIAlertAction(title: "Buat Tanpa Lagu", style: .default) { [weak self] _ in
            IPodMusicLibrary.shared.createNativePlaylist(name: playlistName, tracksToAdd: []) { _ in
                self?.renderTopMenu(restoreIndex: 1)
            }
        })
        sheet.addAction(UIAlertAction(title: "Batal", style: .cancel))
        present(sheet, animated: true)
    }

    // MARK: - ClickWheelDelegate
    func clickWheelDidScroll(steps: Int) {
        if isNowPlayingActive {
            if let slider = MPVolumeView().subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = min(max(0, slider.value + Float(steps) * 0.06), 1.0)
            }
            return
        }

        if let top = menuStack.last, case .streamingSongs(let pageIndex) = top.node {
            let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: pageIndex)
            let proposed = screenView.selectedIndex + steps
            if pageData.totalPages > 1 {
                if proposed >= pageData.tracks.count {
                    let nextPage = (pageData.currentPage + 1) % pageData.totalPages
                    menuStack[menuStack.count - 1] = (.streamingSongs(pageIndex: nextPage), 0)
                    renderTopMenu(restoreIndex: 0)
                    return
                } else if proposed < 0 && pageData.currentPage > 0 {
                    let prevPage = pageData.currentPage - 1
                    let prevCount = IPodStreamingLibrary.shared.tracksPage(pageIndex: prevPage).tracks.count
                    menuStack[menuStack.count - 1] = (.streamingSongs(pageIndex: prevPage), max(0, prevCount - 1))
                    renderTopMenu(restoreIndex: max(0, prevCount - 1))
                    return
                }
            }
        }

        screenView.moveSelection(by: steps)
    }

    func clickWheelDidPressMenu() {
        if isNowPlayingActive {
            let activeIndex: Int
            if let top = menuStack.last, case .allSongs = top.node,
               currentQueue.indices.contains(currentTrackIndex),
               let matchedSongIdx = IPodMusicLibrary.shared.allTracks.firstIndex(where: { $0.id == currentQueue[currentTrackIndex].id }) {
                activeIndex = matchedSongIdx
                menuStack[menuStack.count - 1].selectedIndex = matchedSongIdx
            } else {
                activeIndex = menuStack.last?.selectedIndex ?? 0
            }
            renderTopMenu(restoreIndex: activeIndex, animateFromNowPlaying: true)
            return
        }
        if menuStack.count > 1 {
            menuStack.removeLast()
            let prevIndex = menuStack.last?.selectedIndex ?? 0
            renderTopMenu(restoreIndex: prevIndex)
        }
    }

    func clickWheelDidPressSelect() {
        if isNowPlayingActive {
            triggerShuffleSongs()
            return
        }
        guard let top = menuStack.last else { return }
        let idx = screenView.selectedIndex

        switch top.node {
        case .root:
            if idx == 0 {
                if isPlaylistsMenuEnabled {
                    pushMenu(.music)
                } else {
                    pushMenu(.allSongs)
                }
            } else if idx == 1 {
                pushMenu(.streamingSongs(pageIndex: 0))
            } else if idx == 2 {
                pushMenu(.settings)
            }

        case .music:
            switch idx {
            case 0: pushMenu(.playlists)
            case 1: pushMenu(.allSongs)
            default: break
            }

        case .streamingSongs(let pageIndex):
            let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: pageIndex)
            if pageData.tracks.indices.contains(idx) {
                let chosen = pageData.tracks[idx]
                startQueue(
                    tracks: IPodStreamingLibrary.shared.allStreamingTracks,
                    at: 0,
                    selectedTrack: chosen,
                    useRelatedOrder: true
                )
            }

        case .playlists:
            if idx == 0 {
                presentCreatePlaylistDialog()
            } else {
                let pls = IPodMusicLibrary.shared.playlists
                let plIndex = idx - 1
                if pls.indices.contains(plIndex) {
                    pushMenu(.playlistTracks(pls[plIndex]))
                }
            }

        case .playlistTracks(let group):
            if group.tracks.indices.contains(idx) {
                startQueue(tracks: group.tracks, at: idx, useRelatedOrder: false)
            }

        case .allSongs:
            let songs = IPodMusicLibrary.shared.allTracks
            if songs.indices.contains(idx) {
                startQueue(tracks: songs, at: idx, useRelatedOrder: false)
            }

        case .settings:
            if idx == 0 {
                let allThemes = IPodColorTheme.allCases
                if let currentIdx = allThemes.firstIndex(of: screenView.theme) {
                    screenView.theme = allThemes[(currentIdx + 1) % allThemes.count]
                    applyThemeToBodyAndWheel()
                }
                renderTopMenu(restoreIndex: 0)
            } else if idx == 1 {
                isPlaylistsMenuEnabled.toggle()
                UserDefaults.standard.set(isPlaylistsMenuEnabled, forKey: "ipod_playlists_enabled")
                renderTopMenu(restoreIndex: 1)
            } else if idx == 2 {
                toggleHomeScreenAppIcon()
            } else if idx == 3 {
                IPodMusicLibrary.shared.reloadAllSources()
                renderTopMenu(restoreIndex: 3)
            }
        }
    }

    func clickWheelDidPressPlayPause() {
        if !isNowPlayingActive && (currentQueue.isEmpty || !isPlaying) {
            triggerShuffleSongs()
            return
        }
        togglePlayPause()
    }

    func clickWheelDidPressNext() {
        playNextTrack()
    }

    func clickWheelDidPressPrevious() {
        playPreviousTrack()
    }

    // MARK: - Native AVPlayer Audio Engine
    private func startQueue(tracks: [IPodTrack], at index: Int, selectedTrack: IPodTrack? = nil, useRelatedOrder: Bool = false) {
        guard !tracks.isEmpty else { return }
        let targetTrack: IPodTrack
        if let explicit = selectedTrack {
            targetTrack = explicit
        } else if tracks.indices.contains(index) {
            targetTrack = tracks[index]
        } else {
            return
        }

        let wasCoverFlow = screenView.isCoverFlowActive
        if !menuStack.isEmpty {
            menuStack[menuStack.count - 1].selectedIndex = index
        }

        if !useRelatedOrder && currentQueue.indices.contains(currentTrackIndex),
           currentQueue[currentTrackIndex].id == targetTrack.id,
           player != nil {
            if !isPlaying {
                player?.play()
                isPlaying = true
                screenView.updatePlayState(isPlaying: true)
            }
            openNowPlayingScreen(animateFromCoverFlow: wasCoverFlow)
            return
        }

        if useRelatedOrder {
            isShuffleActive = false
            currentQueue = IPodStreamingLibrary.shared.buildRelatedQueue(startingWith: targetTrack, in: tracks)
            currentTrackIndex = 0
        } else {
            currentQueue = tracks
            currentTrackIndex = tracks.firstIndex(where: { $0.id == targetTrack.id }) ?? max(0, min(index, tracks.count - 1))
        }

        playTrack(at: currentTrackIndex, transitionDirection: 0)
        openNowPlayingScreen(animateFromCoverFlow: wasCoverFlow)
    }

    private func openNowPlayingScreen(transitionDirection: Int = 0, animateFromCoverFlow: Bool = false) {
        guard currentQueue.indices.contains(currentTrackIndex) else { return }
        isNowPlayingActive = true
        let track = currentQueue[currentTrackIndex]
        screenView.showNowPlaying(
            track: track,
            index: currentTrackIndex,
            total: currentQueue.count,
            transitionDirection: transitionDirection,
            animateFromCoverFlow: animateFromCoverFlow
        )
    }

    private func playTrack(at index: Int, transitionDirection: Int = 0) {
        guard currentQueue.indices.contains(index) else { return }
        let track = currentQueue[index]

        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }

        isPlaying = true
        playingTrackArtwork = track.artworkImage
        screenView.updatePlayState(isPlaying: true)
        updateAmbientGlow(from: track.artworkImage)

        if isNowPlayingActive {
            screenView.showNowPlaying(
                track: track,
                index: index,
                total: currentQueue.count,
                transitionDirection: transitionDirection,
                animateFromCoverFlow: false
            )
        }

        IPodStreamingLibrary.shared.resolvePlayableAudioURL(for: track) { [weak self] resolvedURL in
            guard let self = self else { return }
            guard self.currentQueue.indices.contains(self.currentTrackIndex),
                  self.currentQueue[self.currentTrackIndex].id == track.id else { return }

            let playableURL = resolvedURL ?? IPodStreamingLibrary.shared.fallbackAudioURL(for: track)
            guard let url = playableURL else { return }

            let item = AVPlayerItem(url: url)
            self.player = AVPlayer(playerItem: item)
            self.player?.play()

            self.endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.playNextTrack()
            }

            self.startProgressTimer()
            self.updateNowPlayingInfo(track: track, elapsed: 0)
        }
    }

    private func seekToRatio(_ ratio: Double, isFinished: Bool) {
        guard let player = player, currentQueue.indices.contains(currentTrackIndex) else { return }
        let track = currentQueue[currentTrackIndex]
        let itemDur = player.currentItem.map { CMTimeGetSeconds($0.duration) } ?? track.duration
        let validDur = (itemDur.isFinite && itemDur > 0) ? itemDur : track.duration
        guard validDur > 0 else { return }

        let targetSec = validDur * ratio
        screenView.updateProgress(elapsed: targetSec, duration: validDur, fromScrub: true)

        if isFinished {
            let targetTime = CMTime(seconds: targetSec, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                if self?.isPlaying == true && player.rate == 0 {
                    player.play()
                }
            }
            updateNowPlayingInfo(track: track, elapsed: targetSec)
        }
    }

    private func togglePlayPause() {
        guard let player = player, currentQueue.indices.contains(currentTrackIndex) else {
            triggerShuffleSongs()
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
        playTrack(at: currentTrackIndex, transitionDirection: 1)
    }

    private func playPreviousTrack() {
        guard !currentQueue.isEmpty else { return }
        if let player = player, CMTimeGetSeconds(player.currentTime()) > 4.0 {
            player.seek(to: .zero)
            return
        }
        currentTrackIndex = (currentTrackIndex - 1 + currentQueue.count) % currentQueue.count
        playTrack(at: currentTrackIndex, transitionDirection: -1)
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