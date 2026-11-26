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
    private let mirrorContainerView = UIView()
    private let mirrorReflectionImageView = UIImageView()
    private let mirrorMaskView = UIImageView()
    private let screenView = IPodScreenView()
    private let clickWheel = ClickWheelView()

    private var menuStack: [(node: IPodMenuNode, selectedIndex: Int)] = [(.root, 0)]
    private var isNowPlayingActive = false
    private var nowPlayingBarMode: IPodNowPlayingBarMode = .duration
    private var activeStreamingSearchQuery: String?
    private var sleepSetMinutes: Int = 0
    private var sleepElapsedSeconds: Int = 0
    private var isSleepTimerActive: Bool = false
    private var sleepActivationTimer: Timer?
    private var sleepCountdownTimer: Timer?
    private var sleepFadeTimer: Timer?
    private var sleepVolumeScale: Float = 1.0
    private var isPlaylistsMenuEnabled: Bool = true
    private var isAmbientGlowEnabled: Bool = true
    private var currentGlowColor = UIColor(red: 0.25, green: 0.52, blue: 0.92, alpha: 1.0)
    private var playingTrackArtwork: UIImage?
    private var lastGlowSize: CGSize = .zero
    private var lastMirrorSize: CGSize = .zero
    private let hiddenVolumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    private var volumeObserver: NSKeyValueObservation?

    private var player: AVPlayer?
    private var playbackTimer: Timer?
    private var endObserver: Any?
    private var stallObserver: Any?
    private var failedEndObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var currentQueue: [IPodTrack] = []
    private var currentTrackIndex: Int = 0
    private var isPlaying = false
    private var isShuffleActive = false

    // Stream Watchdog Tweak state
    private var lastObservedElapsed: TimeInterval = -1
    private var stuckTicks: Int = 0
    private var startupStuckTicks: Int = 0
    private var watchdogRecoveriesForCurrentTrack: Int = 0
    private var currentStreamFallbacks: [(url: URL, userAgent: String)] = []
    private var didTryAndroidFallbackForCurrentTrack = false
    private var lastWheelSeekTime: TimeInterval = 0
    private var lastWheelSeekTarget: TimeInterval = 0

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isPlaylistsMenuEnabled = UserDefaults.standard.object(forKey: "ipod_playlists_enabled") as? Bool ?? true
        isAmbientGlowEnabled = UserDefaults.standard.object(forKey: "ipod_ambient_glow_enabled") as? Bool ?? true
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
            guard let self = self else { return }
            switch self.nowPlayingBarMode {
            case .duration:
                self.seekToRatio(ratio, isFinished: isFinished)
            case .volume:
                self.setSystemVolume(Float(ratio))
            case .sleepTimer:
                let mins = Int(round(min(max(ratio, 0.0), 1.0) * 60.0))
                self.setSleepTimerMinutes(mins, startActivationCountdown: isFinished)
            }
        }

        screenView.onActiveCoverImageChanged = { [weak self] image in
            self?.updateAmbientGlow(from: image)
        }

        screenView.onStreamingRefreshTapped = { [weak self] in
            self?.refreshStreamingList()
        }

        screenView.onStreamingSearchTapped = { [weak self] in
            self?.presentStreamingSearchPopup()
        }

        IPodStreamingLibrary.shared.onTrackArtworkLoaded = { [weak self] trackId, image in
            guard let self = self else { return }
            self.screenView.updateCoverTrackArtwork(trackId: trackId, image: image)
            if let qIdx = self.currentQueue.firstIndex(where: { $0.id == trackId }) {
                let old = self.currentQueue[qIdx]
                let updated = IPodTrack(
                    id: old.id,
                    title: old.title,
                    artist: old.artist,
                    album: old.album,
                    duration: old.duration,
                    assetURL: old.assetURL,
                    mediaItem: old.mediaItem,
                    artworkImage: image
                )
                self.currentQueue[qIdx] = updated
                if qIdx == self.currentTrackIndex {
                    self.playingTrackArtwork = image
                    self.updateAmbientGlow(from: image)
                    if self.isNowPlayingActive {
                        self.screenView.showNowPlaying(
                            track: updated,
                            index: self.currentTrackIndex,
                            total: self.currentQueue.count,
                            transitionDirection: 0,
                            animateFromCoverFlow: false
                        )
                    }
                    let elapsed = self.player.map { CMTimeGetSeconds($0.currentTime()) } ?? 0
                    self.updateNowPlayingInfo(track: updated, elapsed: elapsed.isFinite ? elapsed : 0)
                }
            }
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
        let wheelFrameInGlow = clickWheel.convert(clickWheel.bounds, to: ambientGlowImageView)
        if glowSize.width > 0, glowSize.height > 0,
           screenFrameInGlow.width > 0, wheelFrameInGlow.width > 0,
           glowSize != lastGlowSize {
            lastGlowSize = glowSize
            ambientGlowImageView.image = makeSmoothLcdAmbientImage(
                canvasSize: glowSize,
                lcdRect: screenFrameInGlow
            )
        }

        let mirrorSize = mirrorContainerView.bounds.size
        if mirrorSize.width > 0, mirrorSize.height > 0, mirrorSize != lastMirrorSize {
            lastMirrorSize = mirrorSize
            mirrorMaskView.frame = mirrorContainerView.bounds
            mirrorMaskView.image = makeMirrorFadeMaskImage(size: mirrorSize)
        }
    }

    private func setupBodyAndLayout() {
        view.layer.insertSublayer(bodyGradient, at: 0)

        ambientGlowImageView.contentMode = .scaleToFill
        ambientGlowImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ambientGlowImageView)

        mirrorContainerView.clipsToBounds = true
        mirrorContainerView.isUserInteractionEnabled = false
        mirrorContainerView.translatesAutoresizingMaskIntoConstraints = false
        mirrorContainerView.mask = mirrorMaskView
        view.addSubview(mirrorContainerView)

        mirrorReflectionImageView.contentMode = .scaleAspectFill
        mirrorReflectionImageView.clipsToBounds = true
        mirrorReflectionImageView.alpha = 0.36
        mirrorReflectionImageView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
        mirrorReflectionImageView.translatesAutoresizingMaskIntoConstraints = false
        mirrorContainerView.addSubview(mirrorReflectionImageView)

        screenView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(screenView)

        clickWheel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clickWheel)

        hiddenVolumeView.alpha = 0.01
        hiddenVolumeView.isUserInteractionEnabled = false
        view.addSubview(hiddenVolumeView)

        NSLayoutConstraint.activate([
            screenView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            screenView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            screenView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            screenView.heightAnchor.constraint(equalTo: screenView.widthAnchor, multiplier: 0.80),

            ambientGlowImageView.topAnchor.constraint(equalTo: view.topAnchor),
            ambientGlowImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ambientGlowImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ambientGlowImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            mirrorContainerView.topAnchor.constraint(equalTo: screenView.bottomAnchor, constant: -10),
            mirrorContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mirrorContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mirrorContainerView.bottomAnchor.constraint(equalTo: clickWheel.centerYAnchor, constant: 14),

            mirrorReflectionImageView.topAnchor.constraint(equalTo: mirrorContainerView.topAnchor),
            mirrorReflectionImageView.leadingAnchor.constraint(equalTo: mirrorContainerView.leadingAnchor),
            mirrorReflectionImageView.trailingAnchor.constraint(equalTo: mirrorContainerView.trailingAnchor),
            mirrorReflectionImageView.heightAnchor.constraint(equalTo: mirrorContainerView.widthAnchor),

            clickWheel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -44),
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

        // Soft Gaussian backlight halo around the LCD edges
        let haloPath = UIBezierPath(roundedRect: lcdRect.insetBy(dx: 1.0, dy: 1.0), cornerRadius: 8.0)

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 12.0, color: UIColor.white.withAlphaComponent(0.75).cgColor)
        UIColor.white.setFill()
        haloPath.fill()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 22.0, color: UIColor.white.withAlphaComponent(0.45).cgColor)
        UIColor.white.setFill()
        haloPath.fill()
        ctx.restoreGState()

        let img = UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
        UIGraphicsEndImageContext()
        return img
    }

    private func makeMirrorFadeMaskImage(size: CGSize) -> UIImage? {
        let w = size.width
        let h = size.height
        guard w > 1, h > 1 else { return nil }

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        let outerHaloLeft: CGFloat = 0.0
        let lcdSideLeft = min(0.08, 7.0 / w)
        let flatEdgeLeft = min(0.15, 14.0 / w) // exact LCD leading edge
        let flatEdgeRight = max(0.85, (w - 14.0) / w) // exact LCD trailing edge
        let lcdSideRight = max(0.92, (w - 7.0) / w)
        let outerHaloRight: CGFloat = 1.0

        let hColors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.48).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor,
            UIColor.white.withAlphaComponent(0.48).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let hLocations: [CGFloat] = [outerHaloLeft, lcdSideLeft, flatEdgeLeft, flatEdgeRight, lcdSideRight, outerHaloRight]

        if let hGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: hColors, locations: hLocations) {
            ctx.drawLinearGradient(
                hGrad,
                start: CGPoint(x: 0, y: h * 0.5),
                end: CGPoint(x: w, y: h * 0.5),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        ctx.setBlendMode(.destinationIn)
        let topLcdEdge = min(0.12, 10.0 / h)
        let topPeak = min(0.28, 28.0 / h)
        let vColors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.28).cgColor,
            UIColor.white.withAlphaComponent(0.88).cgColor,
            UIColor.white.withAlphaComponent(0.40).cgColor,
            UIColor.white.withAlphaComponent(0.10).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let vLocations: [CGFloat] = [0.0, topLcdEdge, topPeak, 0.56, 0.85, 1.0]

        if let vGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: vColors, locations: vLocations) {
            ctx.drawLinearGradient(
                vGrad,
                start: CGPoint(x: w * 0.5, y: 0),
                end: CGPoint(x: w * 0.5, y: h),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func applyThemeToBodyAndWheel() {
        let theme = screenView.theme
        clickWheel.applyTheme(theme)

        switch theme {
        case .darkPod:
            bodyGradient.colors = [
                UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1.0).cgColor,
                UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1.0).cgColor
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
        guard isAmbientGlowEnabled else {
            ambientGlowImageView.alpha = 0.0
            mirrorContainerView.alpha = 0.0
            return
        }
        let isDark = (screenView.theme == .darkPod)
        ambientGlowImageView.tintColor = color
        ambientGlowImageView.alpha = isDark ? 0.85 : 0.52
        mirrorContainerView.alpha = isDark ? 1.0 : 0.65
    }

    private func updateAmbientGlow(from image: UIImage?) {
        let reflectionImage = image ?? playingTrackArtwork
        if mirrorReflectionImageView.image !== reflectionImage {
            UIView.transition(
                with: mirrorReflectionImageView,
                duration: 0.35,
                options: [.transitionCrossDissolve]
            ) {
                self.mirrorReflectionImageView.image = reflectionImage
            }
        }

        let glowColor = extractDominantColor(from: reflectionImage) ?? (screenView.theme == .darkPod
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
            return UIColor(hue: h, saturation: min(0.78, max(s * 1.15, 0.24)), brightness: min(0.92, max(b * 1.18, 0.66)), alpha: 1.0)
        }
        return avgColor
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            volumeObserver = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
                DispatchQueue.main.async {
                    guard let self = self, self.isNowPlayingActive, self.nowPlayingBarMode == .volume,
                          let vol = change.newValue else { return }
                    self.screenView.updateVolumeDisplay(vol)
                }
            }
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func currentSystemVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }

    private func setSystemVolume(_ newValue: Float) {
        let clamped = min(max(newValue, 0.0), 1.0)
        if let slider = hiddenVolumeView.subviews.compactMap({ $0 as? UISlider }).first {
            slider.value = clamped
        }
        screenView.updateVolumeDisplay(clamped)
    }

    private var isLightAppIconActive: Bool {
        return UIApplication.shared.alternateIconName == "AppIconLight"
    }

    private func toggleHomeScreenAppIcon() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let nextIconName: String? = isLightAppIconActive ? nil : "AppIconLight"
        UIApplication.shared.setAlternateIconName(nextIconName) { [weak self] _ in
            DispatchQueue.main.async {
                self?.renderTopMenu(restoreIndex: 3)
            }
        }
    }

    private func loadStreamingCatalog(showLoading: Bool = true) {
        activeStreamingSearchQuery = nil
        if showLoading {
            screenView.showCoverFlowLoading(title: "Streaming")
        }
        IPodStreamingLibrary.shared.refreshTracks { [weak self] _ in
            guard let self = self else { return }
            guard let top = self.menuStack.last, case .streamingSongs = top.node, !self.isNowPlayingActive else {
                return
            }
            let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: 0)
            let initialIndex = pageData.tracks.isEmpty ? 0 : 1
            self.menuStack[self.menuStack.count - 1] = (.streamingSongs(pageIndex: 0), initialIndex)
            self.renderTopMenu(restoreIndex: initialIndex)
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    private func refreshStreamingList() {
        loadStreamingCatalog(showLoading: true)
    }

    private func presentStreamingSearchPopup() {
        let alert = UIAlertController(
            title: "Cari Lagu",
            message: "Masukkan judul lagu, nama artis, atau album:",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Contoh: Tulus, Lover, Paper Rings"
            tf.autocapitalizationType = .words
            tf.clearButtonMode = .whileEditing
            tf.returnKeyType = .search
        }
        alert.addAction(UIAlertAction(title: "Cari", style: .default) { [weak self] _ in
            let raw = alert.textFields?.first?.text ?? ""
            let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }
            self?.performStreamingSearch(query: query)
        })
        alert.addAction(UIAlertAction(title: "Batal", style: .cancel))
        present(alert, animated: true)
    }

    private func performStreamingSearch(query: String) {
        activeStreamingSearchQuery = query
        screenView.showCoverFlowLoading(title: query)
        IPodStreamingLibrary.shared.searchSongs(query: query) { [weak self] found in
            guard let self = self else { return }
            guard let top = self.menuStack.last, case .streamingSongs = top.node, !self.isNowPlayingActive else {
                return
            }
            let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: 0)
            let initialIndex = pageData.tracks.isEmpty ? 0 : 1
            self.menuStack[self.menuStack.count - 1] = (.streamingSongs(pageIndex: 0), initialIndex)
            self.renderTopMenu(restoreIndex: initialIndex)
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            if !found {
                self.screenView.showStatusBanner("Lagu tidak ditemukan untuk \"\(query)\"")
            }
        }
    }

    private func triggerShuffleLocalSongs(tracks: [IPodTrack]) {
        guard !tracks.isEmpty else { return }
        var shuffled = tracks.shuffled()
        if currentQueue.indices.contains(currentTrackIndex), shuffled.count > 1 {
            let activeId = currentQueue[currentTrackIndex].id
            if let first = shuffled.first, first.id == activeId {
                shuffled.swapAt(0, Int.random(in: 1..<shuffled.count))
            }
        }
        isShuffleActive = false
        startQueue(tracks: shuffled, at: 0, useRelatedOrder: false)
    }

    private func triggerShuffleStreamingSongs() {
        let pool = IPodStreamingLibrary.shared.allStreamingTracks
        guard !pool.isEmpty else { return }

        var candidates = pool
        if currentQueue.indices.contains(currentTrackIndex), candidates.count > 1 {
            let activeId = currentQueue[currentTrackIndex].id
            candidates.removeAll { $0.id == activeId }
        }
        guard let chosen = candidates.randomElement() ?? pool.randomElement() else { return }

        let wasCoverFlow = screenView.isCoverFlowActive
        isShuffleActive = true
        currentQueue = [chosen]
        currentTrackIndex = 0
        watchdogRecoveriesForCurrentTrack = 0

        playTrack(at: 0, transitionDirection: 0)
        openNowPlayingScreen(animateFromCoverFlow: wasCoverFlow)

        appendRecommendations(for: chosen, replaceUpcoming: true)
    }

    private func appendRecommendations(for seedTrack: IPodTrack, replaceUpcoming: Bool) {
        let seedId = seedTrack.id
        IPodStreamingLibrary.shared.fetchRecommendations(for: seedTrack, limit: 20) { [weak self] recs in
            guard let self = self, self.isShuffleActive else { return }
            guard self.currentQueue.indices.contains(self.currentTrackIndex),
                  self.currentQueue[self.currentTrackIndex].id == seedId else { return }

            let fallbackRelated = IPodStreamingLibrary.shared.buildRelatedQueue(
                startingWith: seedTrack,
                in: IPodStreamingLibrary.shared.allStreamingTracks
            ).dropFirst().prefix(10)

            let chosenRecs = !recs.isEmpty ? recs : Array(fallbackRelated)
            guard !chosenRecs.isEmpty else { return }

            if replaceUpcoming {
                let current = self.currentQueue[self.currentTrackIndex]
                self.currentQueue = [current] + chosenRecs
                self.currentTrackIndex = 0
            } else {
                let existingIds = Set(self.currentQueue.map { $0.id })
                let fresh = chosenRecs.filter { !existingIds.contains($0.id) }
                self.currentQueue.append(contentsOf: fresh)
            }

            if self.isNowPlayingActive && self.currentQueue.indices.contains(self.currentTrackIndex) {
                let active = self.currentQueue[self.currentTrackIndex]
                self.screenView.showNowPlaying(
                    track: active,
                    index: self.currentTrackIndex,
                    total: self.currentQueue.count,
                    transitionDirection: 0,
                    animateFromCoverFlow: false
                )
            }
        }
    }

    // MARK: - Menu Navigation Engine
    private func rows(for node: IPodMenuNode) -> (title: String, items: [IPodMenuRow]) {
        switch node {
        case .root:
            return ("iPod", [
                IPodMenuRow(title: "Music", hasSubmenu: true),
                IPodMenuRow(title: "Streaming", hasSubmenu: true),
                IPodMenuRow(title: "Now Playing", hasSubmenu: true),
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
                    title: "Ambient Glow",
                    hasSubmenu: false,
                    valueBadge: isAmbientGlowEnabled ? "ON" : "OFF",
                    isPositiveToggle: isAmbientGlowEnabled
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
            let baseTitle = activeStreamingSearchQuery ?? "Streaming"
            if IPodStreamingLibrary.shared.isFetchingSongs {
                screenView.showCoverFlowLoading(title: baseTitle)
                return
            }
            let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: pageIndex)
            let header = pageData.totalPages > 1
                ? "\(baseTitle) (\(pageData.currentPage + 1)/\(pageData.totalPages))"
                : baseTitle
            screenView.showSongsCoverFlow(
                title: header,
                tracks: pageData.tracks,
                selectedIndex: restoreIndex,
                animateFromNowPlaying: animateFromNowPlaying,
                showStreamingRefresh: true,
                searchQuery: activeStreamingSearchQuery
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
        if case .streamingSongs = node {
            loadStreamingCatalog(showLoading: true)
            return
        }
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
            switch nowPlayingBarMode {
            case .duration:
                seekBy(seconds: Double(steps) * 5.0)
            case .volume:
                setSystemVolume(currentSystemVolume() + Float(steps) * 0.06)
            case .sleepTimer:
                adjustSleepTimer(byMinutes: steps)
            }
            return
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
            } else if let top = menuStack.last, case .streamingSongs(let pageIndex) = top.node,
                      currentQueue.indices.contains(currentTrackIndex) {
                let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: pageIndex)
                if let matchedIdx = pageData.tracks.firstIndex(where: { $0.id == currentQueue[currentTrackIndex].id }) {
                    activeIndex = matchedIdx + 1
                    menuStack[menuStack.count - 1].selectedIndex = activeIndex
                } else {
                    activeIndex = menuStack.last?.selectedIndex ?? (pageData.tracks.isEmpty ? 0 : 1)
                }
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
            switch nowPlayingBarMode {
            case .duration:
                nowPlayingBarMode = .volume
            case .volume:
                nowPlayingBarMode = .sleepTimer
            case .sleepTimer:
                nowPlayingBarMode = .duration
            }
            screenView.setNowPlayingBarMode(
                nowPlayingBarMode,
                volume: currentSystemVolume(),
                sleepSetMinutes: sleepSetMinutes,
                sleepElapsedSeconds: sleepElapsedSeconds,
                isSleepActive: isSleepTimerActive
            )
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
                if !currentQueue.isEmpty && currentQueue.indices.contains(currentTrackIndex) {
                    if !menuStack.isEmpty {
                        menuStack[menuStack.count - 1].selectedIndex = idx
                    }
                    openNowPlayingScreen(animateFromCoverFlow: false)
                } else {
                    screenView.showStatusBanner("Belum ada lagu yang diputar")
                }
            } else if idx == 3 {
                pushMenu(.settings)
            }

        case .music:
            switch idx {
            case 0: pushMenu(.playlists)
            case 1: pushMenu(.allSongs)
            default: break
            }

        case .streamingSongs(let pageIndex):
            if screenView.isSearchItemSelected {
                presentStreamingSearchPopup()
                return
            }
            if screenView.isRefreshItemSelected {
                refreshStreamingList()
                return
            }
            let pageData = IPodStreamingLibrary.shared.tracksPage(pageIndex: pageIndex)
            if let trackIdx = screenView.selectedCoverTrackIndex, pageData.tracks.indices.contains(trackIdx) {
                let chosen = pageData.tracks[trackIdx]
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
                isAmbientGlowEnabled.toggle()
                UserDefaults.standard.set(isAmbientGlowEnabled, forKey: "ipod_ambient_glow_enabled")
                UIView.animate(withDuration: 0.30) {
                    self.applyGlowColors(self.currentGlowColor)
                }
                renderTopMenu(restoreIndex: 1)
            } else if idx == 2 {
                isPlaylistsMenuEnabled.toggle()
                UserDefaults.standard.set(isPlaylistsMenuEnabled, forKey: "ipod_playlists_enabled")
                renderTopMenu(restoreIndex: 2)
            } else if idx == 3 {
                toggleHomeScreenAppIcon()
            } else if idx == 4 {
                IPodMusicLibrary.shared.reloadAllSources()
                renderTopMenu(restoreIndex: 4)
            }
        }
    }

    func clickWheelDidPressPlayPause() {
        if isPlaying {
            togglePlayPause()
            return
        }
        if isNowPlayingActive {
            togglePlayPause()
            return
        }

        if let top = menuStack.last {
            switch top.node {
            case .allSongs:
                triggerShuffleLocalSongs(tracks: IPodMusicLibrary.shared.allTracks)
                return
            case .playlistTracks(let group):
                triggerShuffleLocalSongs(tracks: group.tracks)
                return
            case .streamingSongs:
                triggerShuffleStreamingSongs()
                return
            default:
                break
            }
        }

        if player != nil {
            togglePlayPause()
        }
    }

    func clickWheelDidPressNext() {
        playNextTrack()
    }

    func clickWheelDidPressPrevious() {
        playPreviousTrack()
    }

    // MARK: - Native AVPlayer Audio Engine + Stream Watchdog Tweak
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
            if case .streamingSongs = menuStack[menuStack.count - 1].node {
                menuStack[menuStack.count - 1].selectedIndex = screenView.selectedIndex
            } else {
                menuStack[menuStack.count - 1].selectedIndex = index
            }
        }

        if currentQueue.indices.contains(currentTrackIndex),
           (currentQueue[currentTrackIndex].id == targetTrack.id
            || (targetTrack.id.hasPrefix("innertube_")
                && currentQueue[currentTrackIndex].assetURL != nil
                && currentQueue[currentTrackIndex].assetURL == targetTrack.assetURL)),
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

        watchdogRecoveriesForCurrentTrack = 0
        playTrack(at: currentTrackIndex, transitionDirection: 0)
        openNowPlayingScreen(animateFromCoverFlow: wasCoverFlow)
    }

    private func openNowPlayingScreen(transitionDirection: Int = 0, animateFromCoverFlow: Bool = false) {
        guard currentQueue.indices.contains(currentTrackIndex) else { return }
        let wasAlreadyNowPlaying = isNowPlayingActive
        isNowPlayingActive = true
        if !wasAlreadyNowPlaying {
            nowPlayingBarMode = .duration
            screenView.setNowPlayingBarMode(
                .duration,
                volume: currentSystemVolume(),
                sleepSetMinutes: sleepSetMinutes,
                sleepElapsedSeconds: sleepElapsedSeconds,
                isSleepActive: isSleepTimerActive
            )
        }
        let track = currentQueue[currentTrackIndex]
        screenView.showNowPlaying(
            track: track,
            index: currentTrackIndex,
            total: currentQueue.count,
            transitionDirection: transitionDirection,
            animateFromCoverFlow: animateFromCoverFlow
        )
    }

    private func clearItemObservers() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        if let obs = stallObserver {
            NotificationCenter.default.removeObserver(obs)
            stallObserver = nil
        }
        if let obs = failedEndObserver {
            NotificationCenter.default.removeObserver(obs)
            failedEndObserver = nil
        }
    }

    private func resetWatchdogState() {
        lastObservedElapsed = -1
        stuckTicks = 0
        startupStuckTicks = 0
    }

    private func playTrack(at index: Int, transitionDirection: Int = 0, resumeFromSeconds: Double = 0, isWatchdogRetry: Bool = false) {
        guard currentQueue.indices.contains(index) else { return }
        let track = currentQueue[index]

        clearItemObservers()
        resetWatchdogState()
        if !isWatchdogRetry {
            watchdogRecoveriesForCurrentTrack = 0
            currentStreamFallbacks = []
            didTryAndroidFallbackForCurrentTrack = false
        }

        isPlaying = true
        playingTrackArtwork = track.artworkImage
        screenView.updatePlayState(isPlaying: true)
        updateAmbientGlow(from: track.artworkImage)

        if isNowPlayingActive && !isWatchdogRetry {
            screenView.showNowPlaying(
                track: track,
                index: index,
                total: currentQueue.count,
                transitionDirection: transitionDirection,
                animateFromCoverFlow: false
            )
        }

        if track.id.hasPrefix("innertube_") {
            let preferAlternate = isWatchdogRetry && didTryAndroidFallbackForCurrentTrack
            IPodStreamingLibrary.shared.resolvePlayableAudio(
                for: track,
                forceRefresh: isWatchdogRetry,
                preferAlternateClient: preferAlternate
            ) { [weak self] result in
                guard let self = self else { return }
                guard self.currentQueue.indices.contains(self.currentTrackIndex),
                      self.currentQueue[self.currentTrackIndex].id == track.id else { return }

                switch result {
                case .playable(let stream):
                    var updatedTrack = track
                    if let realDur = stream.duration, realDur > 0 {
                        updatedTrack = IPodTrack(
                            id: track.id,
                            title: track.title,
                            artist: track.artist,
                            album: track.album,
                            duration: realDur,
                            assetURL: track.assetURL,
                            mediaItem: track.mediaItem,
                            artworkImage: track.artworkImage
                        )
                        self.currentQueue[self.currentTrackIndex] = updatedTrack
                        if self.isNowPlayingActive {
                            self.screenView.updateProgress(elapsed: resumeFromSeconds, duration: realDur)
                        }
                    }
                    self.currentStreamFallbacks = stream.fallbackCandidates
                    self.startAVPlayer(with: stream.url, userAgent: stream.userAgent, track: updatedTrack, resumeFromSeconds: resumeFromSeconds)
                case .failed(let reason):
                    self.screenView.showStatusBanner("Gagal Putar: \(reason)")
                    self.playNextTrack()
                }
            }
            return
        }

        if let url = track.assetURL {
            startAVPlayer(with: url, userAgent: nil, track: track, resumeFromSeconds: resumeFromSeconds)
        } else {
            isPlaying = false
            screenView.updatePlayState(isPlaying: false)
            screenView.showStatusBanner("Gagal Putar: Asset URL kosong")
        }
    }

    private func startAVPlayer(with url: URL, userAgent: String?, track: IPodTrack, resumeFromSeconds: Double = 0) {
        clearItemObservers()
        let asset: AVURLAsset
        if url.isFileURL || userAgent == nil {
            asset = AVURLAsset(url: url)
        } else {
            let headers: [String: String] = ["User-Agent": userAgent!]
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }
        let item = AVPlayerItem(asset: asset)
        if !url.isFileURL {
            item.preferredForwardBufferDuration = 20.0
        }

        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.automaticallyWaitsToMinimizeStalling = true
        avPlayer.volume = sleepVolumeScale
        player = avPlayer
        if resumeFromSeconds > 1.0 {
            let seekTarget = CMTime(seconds: resumeFromSeconds, preferredTimescale: 600)
            player?.seek(to: seekTarget, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.player?.play()
            }
        } else {
            player?.play()
        }

        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard self.currentQueue.indices.contains(self.currentTrackIndex),
                      self.currentQueue[self.currentTrackIndex].id == track.id else { return }

                switch observedItem.status {
                case .readyToPlay:
                    let dur = CMTimeGetSeconds(observedItem.duration)
                    if dur.isFinite && dur > 0 {
                        self.updateNowPlayingInfo(track: track, elapsed: max(0, CMTimeGetSeconds(observedItem.currentTime())))
                    }
                case .failed:
                    self.handlePlayerItemFailure(for: track, item: observedItem)
                default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.playNextTrack()
        }

        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            // Give AVPlayer a chance to buffer & resume smoothly instead of tearing it down immediately
            if self.player?.rate == 0 && item.isPlaybackLikelyToKeepUp {
                self.player?.play()
            }
        }

        failedEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlayerItemFailure(for: track, item: item)
        }

        startProgressTimer()
        updateNowPlayingInfo(track: track, elapsed: resumeFromSeconds)
    }

    private func handlePlayerItemFailure(for track: IPodTrack, item: AVPlayerItem) {
        guard currentQueue.indices.contains(currentTrackIndex),
              currentQueue[currentTrackIndex].id == track.id else { return }

        if !currentStreamFallbacks.isEmpty {
            let nextCandidate = currentStreamFallbacks.removeFirst()
            let curSec = CMTimeGetSeconds(item.currentTime())
            let resumeSec = (curSec.isFinite && curSec > 1.0) ? curSec : 0
            resetWatchdogState()
            startAVPlayer(with: nextCandidate.url, userAgent: nextCandidate.userAgent, track: track, resumeFromSeconds: resumeSec)
            return
        }

        if track.id.hasPrefix("innertube_") && !didTryAndroidFallbackForCurrentTrack {
            didTryAndroidFallbackForCurrentTrack = true
            IPodStreamingLibrary.shared.invalidateCachedURL(for: track)
            playTrack(at: currentTrackIndex, transitionDirection: 0, resumeFromSeconds: 0, isWatchdogRetry: true)
            return
        }

        let errDesc = item.error?.localizedDescription ?? "Stream gagal dimuat"
        screenView.showStatusBanner("Gagal Putar: \(errDesc)")
        triggerWatchdogRecovery(for: track, item: item)
    }

    private func triggerWatchdogRecovery(for track: IPodTrack, item: AVPlayerItem) {
        guard isPlaying, currentQueue.indices.contains(currentTrackIndex),
              currentQueue[currentTrackIndex].id == track.id else { return }

        let currentSec = CMTimeGetSeconds(item.currentTime())
        let safeSec = currentSec.isFinite && currentSec > 0 ? currentSec : max(0, lastObservedElapsed)
        let totalDur = CMTimeGetSeconds(item.duration)

        if totalDur.isFinite && totalDur > 5.0 && safeSec >= totalDur - 2.5 {
            playNextTrack()
            return
        }

        if !currentStreamFallbacks.isEmpty {
            let nextCandidate = currentStreamFallbacks.removeFirst()
            resetWatchdogState()
            startAVPlayer(with: nextCandidate.url, userAgent: nextCandidate.userAgent, track: track, resumeFromSeconds: safeSec)
            return
        }

        if watchdogRecoveriesForCurrentTrack < 3 {
            watchdogRecoveriesForCurrentTrack += 1
            didTryAndroidFallbackForCurrentTrack = true
            resetWatchdogState()
            IPodStreamingLibrary.shared.invalidateCachedURL(for: track)
            playTrack(at: currentTrackIndex, transitionDirection: 0, resumeFromSeconds: safeSec, isWatchdogRetry: true)
            return
        }

        playNextTrack()
    }

    private func adjustSleepTimer(byMinutes delta: Int) {
        let nextMinutes = min(max(0, sleepSetMinutes + delta), 60)
        setSleepTimerMinutes(nextMinutes, startActivationCountdown: true)
    }

    private func setSleepTimerMinutes(_ minutes: Int, startActivationCountdown: Bool) {
        sleepActivationTimer?.invalidate()
        sleepActivationTimer = nil
        sleepCountdownTimer?.invalidate()
        sleepCountdownTimer = nil
        sleepFadeTimer?.invalidate()
        sleepFadeTimer = nil
        sleepVolumeScale = 1.0
        player?.volume = 1.0
        isSleepTimerActive = false

        sleepSetMinutes = min(max(0, minutes), 60)
        sleepElapsedSeconds = 0
        screenView.updateSleepTimerDisplay(
            setMinutes: sleepSetMinutes,
            elapsedSeconds: 0,
            isActive: false
        )

        if sleepSetMinutes >= 1 && startActivationCountdown {
            sleepActivationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.activateSleepTimer()
            }
        }
    }

    private func startSleepAudioFadeOut(duration: TimeInterval) {
        sleepFadeTimer?.invalidate()
        let safeDuration = max(duration, 0.5)
        let startTime = Date().timeIntervalSinceReferenceDate
        sleepFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, self.isSleepTimerActive else {
                timer.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSinceReferenceDate - startTime
            let progress = min(max(elapsed / safeDuration, 0.0), 1.0)
            // Smooth ease-out volume ramp down to 0
            let nextVol = Float(pow(1.0 - progress, 1.4))
            self.sleepVolumeScale = nextVol
            self.player?.volume = nextVol
            if progress >= 1.0 {
                timer.invalidate()
            }
        }
    }

    private func activateSleepTimer() {
        sleepActivationTimer = nil
        guard sleepSetMinutes >= 1 else { return }

        sleepFadeTimer?.invalidate()
        sleepFadeTimer = nil
        sleepVolumeScale = 1.0
        player?.volume = 1.0
        isSleepTimerActive = true
        sleepElapsedSeconds = 0
        screenView.updateSleepTimerDisplay(
            setMinutes: sleepSetMinutes,
            elapsedSeconds: 0,
            isActive: true
        )

        sleepCountdownTimer?.invalidate()
        sleepCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let targetSeconds = self.sleepSetMinutes * 60
            self.sleepElapsedSeconds = min(targetSeconds, self.sleepElapsedSeconds + 1)
            self.screenView.updateSleepTimerDisplay(
                setMinutes: self.sleepSetMinutes,
                elapsedSeconds: self.sleepElapsedSeconds,
                isActive: true
            )
            let remaining = targetSeconds - self.sleepElapsedSeconds
            if remaining <= 5 && remaining > 0 && self.sleepFadeTimer == nil {
                self.startSleepAudioFadeOut(duration: TimeInterval(remaining))
            }
            if self.sleepElapsedSeconds >= targetSeconds {
                self.sleepCountdownTimer?.invalidate()
                self.sleepCountdownTimer = nil
                self.sleepFadeTimer?.invalidate()
                self.sleepFadeTimer = nil
                self.isSleepTimerActive = false
                self.sleepSetMinutes = 0
                self.sleepElapsedSeconds = 0
                self.screenView.updateSleepTimerDisplay(setMinutes: 0, elapsedSeconds: 0, isActive: false)
                if self.isPlaying {
                    self.togglePlayPause()
                }
                self.sleepVolumeScale = 1.0
                self.player?.volume = 1.0
                self.screenView.showStatusBanner("Waktu tidur selesai • Musik dijeda")
            }
        }
    }

    private func seekBy(seconds delta: Double) {
        guard let player = player, currentQueue.indices.contains(currentTrackIndex) else { return }
        let track = currentQueue[currentTrackIndex]
        let itemDur = player.currentItem.map { CMTimeGetSeconds($0.duration) } ?? track.duration
        let validDur = (itemDur.isFinite && itemDur > 0) ? itemDur : track.duration
        guard validDur > 0 else { return }

        let now = Date().timeIntervalSinceReferenceDate
        let rawCurrent = CMTimeGetSeconds(player.currentTime())
        let baseSec: Double
        if (now - lastWheelSeekTime) < 0.6 {
            baseSec = lastWheelSeekTarget
        } else {
            baseSec = rawCurrent.isFinite ? rawCurrent : max(0.0, lastObservedElapsed)
        }
        let maxTarget = max(0.0, validDur - 0.5)
        let targetSec = min(max(0.0, baseSec + delta), maxTarget)

        lastWheelSeekTime = now
        lastWheelSeekTarget = targetSec
        resetWatchdogState()
        lastObservedElapsed = targetSec
        screenView.updateProgress(elapsed: targetSec, duration: validDur)

        let targetTime = CMTime(seconds: targetSec, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            if self?.isPlaying == true && player.rate == 0 {
                player.play()
            }
        }
        updateNowPlayingInfo(track: track, elapsed: targetSec)
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
            resetWatchdogState()
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
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
            resetWatchdogState()
        } else {
            player.play()
            isPlaying = true
            resetWatchdogState()
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
        if isShuffleActive && currentTrackIndex >= max(0, currentQueue.count - 2) {
            let active = currentQueue[currentTrackIndex]
            if active.id.hasPrefix("innertube_") {
                appendRecommendations(for: active, replaceUpcoming: false)
            }
        }
    }

    private func playPreviousTrack() {
        guard !currentQueue.isEmpty else { return }
        if let player = player, CMTimeGetSeconds(player.currentTime()) > 4.0 {
            player.seek(to: .zero)
            resetWatchdogState()
            return
        }
        currentTrackIndex = (currentTrackIndex - 1 + currentQueue.count) % currentQueue.count
        playTrack(at: currentTrackIndex, transitionDirection: -1)
    }

    private func startProgressTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player, let item = player.currentItem,
                  self.currentQueue.indices.contains(self.currentTrackIndex) else { return }
            let track = self.currentQueue[self.currentTrackIndex]
            let elapsed = CMTimeGetSeconds(player.currentTime())
            let itemDur = CMTimeGetSeconds(item.duration)
            let validDur = (itemDur.isFinite && itemDur > 0) ? itemDur : track.duration

            if elapsed.isFinite {
                self.screenView.updateProgress(elapsed: elapsed, duration: validDur)
                self.updateNowPlayingInfo(track: track, elapsed: elapsed)

                if self.isPlaying && player.rate == 0 {
                    if item.status == .readyToPlay && item.isPlaybackLikelyToKeepUp {
                        player.play()
                    }
                    if elapsed <= 5.0 {
                        self.startupStuckTicks += 1
                        if self.startupStuckTicks >= 16 {
                            self.triggerWatchdogRecovery(for: track, item: item)
                        }
                    } else if abs(elapsed - self.lastObservedElapsed) < 0.25 {
                        self.stuckTicks += 1
                        if self.stuckTicks >= 10 {
                            self.triggerWatchdogRecovery(for: track, item: item)
                        }
                    } else {
                        self.lastObservedElapsed = elapsed
                        self.stuckTicks = 0
                    }
                } else {
                    self.lastObservedElapsed = elapsed
                    self.stuckTicks = 0
                    self.startupStuckTicks = 0
                }
            } else if self.isPlaying && player.rate == 0 {
                self.startupStuckTicks += 1
                if self.startupStuckTicks >= 12 {
                    self.triggerWatchdogRecovery(for: track, item: item)
                }
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