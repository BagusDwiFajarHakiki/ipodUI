import UIKit

enum IPodNowPlayingBarMode {
    case duration
    case lyrics
    case volume
    case sleepTimer
}

enum IPodColorTheme: CaseIterable {
    case darkPod
    case sepiaPod
    case classicBlue

    var displayName: String {
        switch self {
        case .darkPod:     return "Obsidian"
        case .sepiaPod:    return "Sandstone"
        case .classicBlue: return "Glacier"
        }
    }

    var screenBackground: UIColor {
        switch self {
        case .darkPod:     return UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.96, green: 0.92, blue: 0.83, alpha: 1.0)
        case .classicBlue: return UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
        }
    }

    var primaryText: UIColor {
        switch self {
        case .darkPod:     return UIColor(white: 0.96, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.24, green: 0.17, blue: 0.10, alpha: 1.0)
        case .classicBlue: return UIColor(white: 0.10, alpha: 1.0)
        }
    }

    var secondaryText: UIColor {
        switch self {
        case .darkPod:     return UIColor(white: 0.62, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.48, green: 0.37, blue: 0.25, alpha: 1.0)
        case .classicBlue: return UIColor(white: 0.42, alpha: 1.0)
        }
    }

    var highlightTop: UIColor {
        switch self {
        case .darkPod:     return UIColor(red: 0.25, green: 0.52, blue: 0.92, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 1.0)
        case .classicBlue: return UIColor(red: 0.24, green: 0.56, blue: 0.94, alpha: 1.0)
        }
    }

    var highlightBottom: UIColor {
        switch self {
        case .darkPod:     return UIColor(red: 0.14, green: 0.36, blue: 0.74, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.44, green: 0.28, blue: 0.13, alpha: 1.0)
        case .classicBlue: return UIColor(red: 0.11, green: 0.38, blue: 0.80, alpha: 1.0)
        }
    }
}

struct IPodMenuRow {
    let title: String
    let hasSubmenu: Bool
    let valueBadge: String?
    let isPositiveToggle: Bool?

    init(title: String, hasSubmenu: Bool, valueBadge: String? = nil, isPositiveToggle: Bool? = nil) {
        self.title = title
        self.hasSubmenu = hasSubmenu
        self.valueBadge = valueBadge
        self.isPositiveToggle = isPositiveToggle
    }
}

class IPodMenuCell: UITableViewCell {
    private let cardBackground = UIView()
    private let highlightGradient = CAGradientLayer()
    let titleLabel = UILabel()
    let arrowLabel = UILabel()
    private let badgeContainer = UIView()
    private let badgeLabel = UILabel()
    private var badgeWidthConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        cardBackground.layer.cornerRadius = 7
        cardBackground.clipsToBounds = true
        cardBackground.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardBackground)

        highlightGradient.isHidden = true
        highlightGradient.cornerRadius = 7
        cardBackground.layer.insertSublayer(highlightGradient, at: 0)

        titleLabel.font = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(titleLabel)

        arrowLabel.text = "›"
        arrowLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        arrowLabel.textAlignment = .right
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(arrowLabel)

        badgeContainer.layer.cornerRadius = 9
        badgeContainer.isHidden = true
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.addSubview(badgeContainer)

        badgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)

        badgeWidthConstraint = badgeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)

        NSLayoutConstraint.activate([
            cardBackground.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            cardBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            cardBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            cardBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            titleLabel.leadingAnchor.constraint(equalTo: cardBackground.leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -8),

            arrowLabel.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -10),
            arrowLabel.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
            arrowLabel.widthAnchor.constraint(equalToConstant: 14),

            badgeContainer.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -8),
            badgeContainer.centerYAnchor.constraint(equalTo: cardBackground.centerYAnchor),
            badgeContainer.heightAnchor.constraint(equalToConstant: 20),
            badgeWidthConstraint,

            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -8),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layoutIfNeeded()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightGradient.frame = cardBackground.bounds
        CATransaction.commit()
    }

    func configure(row: IPodMenuRow, isSelected: Bool, isModernSettings: Bool, theme: IPodColorTheme) {
        titleLabel.text = row.title
        highlightGradient.colors = [theme.highlightTop.cgColor, theme.highlightBottom.cgColor]

        let hasBadge = (row.valueBadge != nil)
        badgeContainer.isHidden = !hasBadge
        badgeLabel.text = row.valueBadge
        arrowLabel.isHidden = !row.hasSubmenu || hasBadge

        if isModernSettings {
            cardBackground.backgroundColor = theme == .darkPod
                ? UIColor(white: 1.0, alpha: 0.06)
                : UIColor(white: 0.0, alpha: 0.045)
        } else {
            cardBackground.backgroundColor = .clear
        }

        if isSelected {
            highlightGradient.isHidden = false
            titleLabel.textColor = .white
            arrowLabel.textColor = .white
            if let isOn = row.isPositiveToggle {
                badgeContainer.backgroundColor = isOn
                    ? UIColor(red: 0.20, green: 0.78, blue: 0.42, alpha: 1.0)
                    : UIColor(white: 0.0, alpha: 0.30)
                badgeLabel.textColor = .white
            } else {
                badgeContainer.backgroundColor = UIColor(white: 1.0, alpha: 0.22)
                badgeLabel.textColor = .white
            }
        } else {
            highlightGradient.isHidden = true
            titleLabel.textColor = theme.primaryText
            arrowLabel.textColor = theme.secondaryText
            if let isOn = row.isPositiveToggle {
                badgeContainer.backgroundColor = isOn
                    ? UIColor(red: 0.18, green: 0.72, blue: 0.38, alpha: 0.90)
                    : (theme == .darkPod ? UIColor(white: 1.0, alpha: 0.12) : UIColor(white: 0.0, alpha: 0.10))
                badgeLabel.textColor = isOn ? .white : theme.secondaryText
            } else {
                badgeContainer.backgroundColor = theme == .darkPod
                    ? UIColor(white: 1.0, alpha: 0.12)
                    : UIColor(white: 0.0, alpha: 0.08)
                badgeLabel.textColor = theme.primaryText
            }
        }

        setNeedsLayout()
        layoutIfNeeded()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightGradient.frame = cardBackground.bounds
        CATransaction.commit()
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Cover Flow Cell
class IPodCoverFlowCell: UICollectionViewCell {
    let coverImageView = UIImageView()
    let reflectionImageView = UIImageView()
    private let reflectionMask = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false

        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.layer.borderWidth = 0
        coverImageView.layer.borderColor = nil
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(coverImageView)

        reflectionImageView.contentMode = .scaleAspectFill
        reflectionImageView.clipsToBounds = true
        reflectionImageView.alpha = 0.34
        reflectionImageView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
        reflectionImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(reflectionImageView)

        reflectionMask.colors = [
            UIColor.clear.cgColor,
            UIColor(white: 1.0, alpha: 0.45).cgColor,
            UIColor.white.cgColor
        ]
        reflectionMask.locations = [0.05, 0.55, 1.0]
        reflectionImageView.layer.mask = reflectionMask

        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            coverImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: 100),
            coverImageView.heightAnchor.constraint(equalToConstant: 100),

            reflectionImageView.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 1),
            reflectionImageView.centerXAnchor.constraint(equalTo: coverImageView.centerXAnchor),
            reflectionImageView.widthAnchor.constraint(equalToConstant: 100),
            reflectionImageView.heightAnchor.constraint(equalToConstant: 76)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reflectionMask.frame = reflectionImageView.bounds
    }

    func configure(image: UIImage?, showReflection: Bool = true) {
        coverImageView.image = image
        reflectionImageView.isHidden = !showReflection
        reflectionImageView.image = showReflection ? image : nil
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class IPodCircularLoadingView: UIView {
    private let trackLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = 2.6
        layer.addSublayer(trackLayer)

        arcLayer.fillColor = UIColor.clear.cgColor
        arcLayer.lineWidth = 2.6
        arcLayer.lineCap = .round
        arcLayer.strokeStart = 0.0
        arcLayer.strokeEnd = 0.0
        layer.addSublayer(arcLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(1.0, min(bounds.width, bounds.height) / 2.0 - 2.0)
        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -CGFloat.pi / 2.0,
            endAngle: 1.5 * CGFloat.pi,
            clockwise: true
        ).cgPath
        trackLayer.frame = bounds
        trackLayer.path = path
        arcLayer.frame = bounds
        arcLayer.path = path
    }

    func setColor(_ color: UIColor) {
        trackLayer.strokeColor = color.withAlphaComponent(0.22).cgColor
        arcLayer.strokeColor = color.withAlphaComponent(0.92).cgColor
    }

    func setProgress(_ progress: CGFloat) {
        let clamped = min(max(progress, 0.0), 1.0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        arcLayer.strokeEnd = clamped
        CATransaction.commit()
    }
}

final class IPodDownloadStatusButton: UIControl {
    private let iconImageView = UIImageView()
    private let progressRing = IPodCircularLoadingView()
    private var currentState: IPodTrackDownloadState = .notDownloaded
    private var currentTheme: IPodColorTheme = .darkPod

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.55 : 1.0
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.isUserInteractionEnabled = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        progressRing.isHidden = true
        progressRing.isUserInteractionEnabled = false
        progressRing.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressRing)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),

            progressRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressRing.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressRing.widthAnchor.constraint(equalToConstant: 16),
            progressRing.heightAnchor.constraint(equalToConstant: 16)
        ])

        renderState()
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyTheme(_ theme: IPodColorTheme) {
        currentTheme = theme
        renderState()
    }

    func setState(_ state: IPodTrackDownloadState) {
        currentState = state
        renderState()
    }

    private func renderState() {
        switch currentState {
        case .notDownloaded:
            progressRing.isHidden = true
            progressRing.setProgress(0.0)
            iconImageView.isHidden = false
            iconImageView.image = makeDownloadTrayIcon()
            iconImageView.tintColor = currentTheme.secondaryText

        case .downloading(let progress):
            iconImageView.isHidden = true
            progressRing.isHidden = false
            let ringColor = currentTheme == .darkPod ? UIColor.white : currentTheme.highlightTop
            progressRing.setColor(ringColor)
            progressRing.setProgress(CGFloat(progress))

        case .downloaded:
            progressRing.isHidden = true
            progressRing.setProgress(0.0)
            iconImageView.isHidden = false
            iconImageView.image = makeDownloadedCheckIcon()
            iconImageView.tintColor = currentTheme.highlightTop
        }
    }

    private func makeDownloadTrayIcon() -> UIImage? {
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.6)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // Arrow down shaft + head
        ctx.move(to: CGPoint(x: 8.0, y: 2.2))
        ctx.addLine(to: CGPoint(x: 8.0, y: 10.2))
        ctx.move(to: CGPoint(x: 5.0, y: 7.4))
        ctx.addLine(to: CGPoint(x: 8.0, y: 10.5))
        ctx.addLine(to: CGPoint(x: 11.0, y: 7.4))

        // Tray
        ctx.move(to: CGPoint(x: 2.6, y: 11.2))
        ctx.addLine(to: CGPoint(x: 2.6, y: 13.5))
        ctx.addLine(to: CGPoint(x: 13.4, y: 13.5))
        ctx.addLine(to: CGPoint(x: 13.4, y: 11.2))
        ctx.strokePath()

        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
    }

    private func makeDownloadedCheckIcon() -> UIImage? {
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.addEllipse(in: CGRect(x: 1.5, y: 1.5, width: 13.0, height: 13.0))
        ctx.strokePath()

        ctx.setLineWidth(1.7)
        ctx.move(to: CGPoint(x: 5.0, y: 8.2))
        ctx.addLine(to: CGPoint(x: 7.1, y: 10.4))
        ctx.addLine(to: CGPoint(x: 11.2, y: 5.8))
        ctx.strokePath()

        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
    }
}

class IPodScreenView: UIView, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var theme: IPodColorTheme = .darkPod {
        didSet { applyTheme() }
    }

    var onCoverFlowTrackSelected: ((Int) -> Void)?
    var onSeekRatioChanged: ((Double, Bool) -> Void)?
    var onActiveCoverImageChanged: ((UIImage?) -> Void)?
    var onStreamingRefreshTapped: (() -> Void)?
    var onStreamingSearchTapped: (() -> Void)?
    var onDownloadButtonTapped: (() -> Void)?
    var onArtworkDoubleTapped: (() -> Void)?

    // Modern Seamless Status Bar
    private let headerBar = UIView()
    private let headerSubtleTint = CAGradientLayer()
    private let headerTitleLabel = UILabel()
    private let clockLabel = UILabel()
    private let playStateIcon = UILabel()
    private let batteryView = UIView()
    private let batteryCapView = UIView()
    private let batteryFill = UIView()
    private let batteryPercentLabel = UILabel()
    private var batteryWidthConstraint: NSLayoutConstraint!
    private var clockTimer: Timer?

    // Banner Status Toast
    private let statusBannerContainer = UIView()
    private let statusBannerAccentView = UIView()
    private let statusBannerLabel = UILabel()
    private var statusBannerIsError = false
    private var statusBannerTimer: Timer?

    // Menu List View
    private let tableView = UITableView()
    private var rows: [IPodMenuRow] = []
    private(set) var selectedIndex: Int = 0
    private var isModernSettingsMenu = false

    // Horizontal Cover Flow View
    private enum CoverFlowItem {
        case track(IPodTrack)
        case search
        case refresh
    }

    private let coverFlowContainer = UIView()
    private var coverCollectionView: UICollectionView!
    private let coverCaptionStack = UIStackView()
    private let coverTitleLabel = UILabel()
    private let coverArtistLabel = UILabel()
    private let coverLoadingStack = UIStackView()
    private let coverLoadingSpinner = UIActivityIndicatorView(style: .whiteLarge)
    private let coverLoadingLabel = UILabel()
    private var coverTracks: [IPodTrack] = []
    private var coverItems: [CoverFlowItem] = []
    private var hasLeadingSearch = false
    private var activeSearchQuery: String?
    private(set) var isCoverFlowActive = false
    private(set) var isCoverFlowOffline = false
    private let coverItemWidth: CGFloat = 104
    private let coverItemSpacing: CGFloat = -60
    private var displayLink: CADisplayLink?
    private var targetCoverOffsetX: CGFloat = 0

    var isSearchItemSelected: Bool {
        guard isCoverFlowActive, coverItems.indices.contains(selectedIndex) else { return false }
        if case .search = coverItems[selectedIndex] { return true }
        return false
    }

    var isRefreshItemSelected: Bool {
        guard isCoverFlowActive, coverItems.indices.contains(selectedIndex) else { return false }
        if case .refresh = coverItems[selectedIndex] { return true }
        return false
    }

    var selectedCoverTrackIndex: Int? {
        guard isCoverFlowActive, coverItems.indices.contains(selectedIndex) else { return nil }
        if case .track = coverItems[selectedIndex] {
            let idx = selectedIndex - (hasLeadingSearch ? 1 : 0)
            return coverTracks.indices.contains(idx) ? idx : nil
        }
        return nil
    }

    // Now Playing View
    private let nowPlayingContainer = UIView()
    private let artworkView = UIImageView()
    private let artworkReflectionView = UIImageView()
    private let artworkReflectionMask = CAGradientLayer()
    private let trackTitleLabel = UILabel()
    private let trackArtistLabel = UILabel()
    private let trackIndexLabel = UILabel()
    private let downloadStatusButton = IPodDownloadStatusButton()
    private var isCurrentTrackStreaming = false
    private let lyricsContainerView = UIView()
    private let lyricsSlotsContainer = UIView()
    private let lyricStatusLabel = UILabel()
    private var lyricLabelsByIndex: [Int: UILabel] = [:]
    private let instrumentalSpinnerView = IPodCircularLoadingView()
    private var titleNormalConstraints: [NSLayoutConstraint] = []
    private var titleLyricsConstraints: [NSLayoutConstraint] = []
    private let progressTouchArea = UIView()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let progressKnob = UIView()
    private let elapsedLabel = UILabel()
    private let remainingLabel = UILabel()
    private let volumeMuteIconView = UIImageView()
    private let volumeFullIconView = UIImageView()
    private let sleepCountdownLabel = UILabel()
    private let sleepTargetLabel = UILabel()
    private var progressWidthConstraint: NSLayoutConstraint!
    private var isScrubbing = false
    private(set) var barMode: IPodNowPlayingBarMode = .duration
    private var lastElapsed: TimeInterval = 0
    private var lastDuration: TimeInterval = 1
    private var currentVolumeLevel: Float = 0.5
    private var lastSleepSetMinutes: Int = 0
    private var lastSleepElapsedSeconds: Int = 0
    private var lastSleepActive: Bool = false
    private var lastDisplayedTrackId: String?

    // Lyrics State
    private enum LyricDisplayItem {
        case line(lineIndex: Int, text: String, startTime: TimeInterval?)
        case instrumental(startTime: TimeInterval, endTime: TimeInterval, isIntro: Bool)
    }

    private var currentLyrics: IPodTrackLyrics?
    private var lyricDisplayItems: [LyricDisplayItem] = []
    private var lyricsLoadingTrackId: String?
    private var lyricsUnavailableTrackId: String?
    private var activeDisplayIndex: Int?
    private var displayLyricCenterIndex: Int = 0
    private var isLyricsAutoScroll: Bool = true
    private var isPlaybackRunningForLyrics: Bool = false
    private var lastLyricsSyncElapsed: TimeInterval = 0
    private var lastLyricsSyncTimestamp: CFTimeInterval = CACurrentMediaTime()
    private var lyricsDisplayLink: CADisplayLink?
    private var lastLyricsLayoutSize: CGSize = .zero
    private var lyricStyledActiveByIndex: [Int: Bool] = [:]
    private var cachedDisplayHeights: [CGFloat] = []
    private var cachedMeasureWidth: CGFloat = 0
    private var visualLyricPos: CGFloat = 0
    private var targetLyricPos: CGFloat = 0
    private var lyricAnimStartPos: CGFloat = 0
    private var lyricAnimStartTime: CFTimeInterval = 0
    private var lyricAnimDuration: TimeInterval = 0
    private var isManualFastScrolling: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 8
        layer.borderWidth = 0
        layer.borderColor = nil
        clipsToBounds = true
        setupUI()
        applyTheme()
        startClockTimer()
    }

    deinit {
        clockTimer?.invalidate()
        displayLink?.invalidate()
        lyricsDisplayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        headerBar.backgroundColor = .clear
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerBar)

        headerSubtleTint.locations = [0.0, 1.0]
        headerBar.layer.insertSublayer(headerSubtleTint, at: 0)

        headerTitleLabel.text = "iPod"
        headerTitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        headerTitleLabel.textAlignment = .left
        headerTitleLabel.lineBreakMode = .byTruncatingTail
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(headerTitleLabel)

        clockLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        clockLabel.textAlignment = .center
        clockLabel.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(clockLabel)

        playStateIcon.text = "❚❚"
        playStateIcon.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        playStateIcon.textAlignment = .right
        playStateIcon.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(playStateIcon)

        batteryView.layer.borderWidth = 1.2
        batteryView.layer.cornerRadius = 3.5
        batteryView.clipsToBounds = true
        batteryView.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(batteryView)

        batteryCapView.layer.cornerRadius = 1.0
        batteryCapView.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(batteryCapView)

        batteryFill.layer.cornerRadius = 2.0
        batteryFill.translatesAutoresizingMaskIntoConstraints = false
        batteryView.addSubview(batteryFill)

        batteryPercentLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 8.0, weight: .heavy)
        batteryPercentLabel.textAlignment = .center
        batteryPercentLabel.translatesAutoresizingMaskIntoConstraints = false
        batteryView.addSubview(batteryPercentLabel)

        // Menu Table
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(IPodMenuCell.self, forCellReuseIdentifier: "IPodCell")
        tableView.rowHeight = 40
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.isUserInteractionEnabled = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)

        // Cover Flow Container
        coverFlowContainer.isHidden = true
        coverFlowContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coverFlowContainer)

        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumLineSpacing = coverItemSpacing
        flowLayout.itemSize = CGSize(width: coverItemWidth, height: 184)

        coverCollectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        coverCollectionView.dataSource = self
        coverCollectionView.delegate = self
        coverCollectionView.register(IPodCoverFlowCell.self, forCellWithReuseIdentifier: "CoverCell")
        coverCollectionView.backgroundColor = .clear
        coverCollectionView.showsHorizontalScrollIndicator = false
        coverCollectionView.decelerationRate = .fast
        coverCollectionView.translatesAutoresizingMaskIntoConstraints = false
        coverFlowContainer.addSubview(coverCollectionView)

        let bottomCaptionGuide = UILayoutGuide()
        coverFlowContainer.addLayoutGuide(bottomCaptionGuide)

        coverCaptionStack.axis = .vertical
        coverCaptionStack.alignment = .center
        coverCaptionStack.spacing = 2
        coverCaptionStack.isUserInteractionEnabled = false
        coverCaptionStack.translatesAutoresizingMaskIntoConstraints = false
        coverFlowContainer.addSubview(coverCaptionStack)

        coverTitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        coverTitleLabel.textAlignment = .center
        coverTitleLabel.lineBreakMode = .byTruncatingTail
        coverCaptionStack.addArrangedSubview(coverTitleLabel)

        coverArtistLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        coverArtistLabel.textAlignment = .center
        coverArtistLabel.lineBreakMode = .byTruncatingTail
        coverCaptionStack.addArrangedSubview(coverArtistLabel)

        coverLoadingStack.axis = .vertical
        coverLoadingStack.alignment = .center
        coverLoadingStack.spacing = 10
        coverLoadingStack.isHidden = true
        coverLoadingStack.translatesAutoresizingMaskIntoConstraints = false
        coverFlowContainer.addSubview(coverLoadingStack)

        coverLoadingSpinner.hidesWhenStopped = true
        coverLoadingStack.addArrangedSubview(coverLoadingSpinner)

        coverLoadingLabel.text = "Memuat lagu..."
        coverLoadingLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        coverLoadingLabel.textAlignment = .center
        coverLoadingStack.addArrangedSubview(coverLoadingLabel)

        // Now Playing Container
        nowPlayingContainer.isHidden = true
        nowPlayingContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nowPlayingContainer)

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.borderWidth = 0
        artworkView.layer.borderColor = nil
        artworkView.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        artworkView.isUserInteractionEnabled = true
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        let doubleTapArtwork = UITapGestureRecognizer(target: self, action: #selector(handleArtworkDoubleTap))
        doubleTapArtwork.numberOfTapsRequired = 2
        artworkView.addGestureRecognizer(doubleTapArtwork)
        nowPlayingContainer.addSubview(artworkView)

        artworkReflectionView.contentMode = .scaleAspectFill
        artworkReflectionView.clipsToBounds = true
        artworkReflectionView.alpha = 0.28
        artworkReflectionView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
        artworkReflectionView.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(artworkReflectionView)

        artworkReflectionMask.colors = [
            UIColor.clear.cgColor,
            UIColor(white: 1.0, alpha: 0.45).cgColor,
            UIColor.white.cgColor
        ]
        artworkReflectionMask.locations = [0.05, 0.55, 1.0]
        artworkReflectionView.layer.mask = artworkReflectionMask

        trackTitleLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
        trackTitleLabel.numberOfLines = 2
        trackTitleLabel.lineBreakMode = .byTruncatingTail
        trackTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(trackTitleLabel)

        trackArtistLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        trackArtistLabel.numberOfLines = 1
        trackArtistLabel.lineBreakMode = .byTruncatingTail
        trackArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(trackArtistLabel)

        trackIndexLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        trackIndexLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(trackIndexLabel)

        downloadStatusButton.isHidden = true
        downloadStatusButton.translatesAutoresizingMaskIntoConstraints = false
        downloadStatusButton.addTarget(self, action: #selector(handleDownloadButtonTap), for: .touchUpInside)
        nowPlayingContainer.addSubview(downloadStatusButton)

        lyricsContainerView.clipsToBounds = true
        lyricsContainerView.isHidden = true
        lyricsContainerView.alpha = 0.0
        lyricsContainerView.isUserInteractionEnabled = true
        lyricsContainerView.translatesAutoresizingMaskIntoConstraints = false
        let tapLyrics = UITapGestureRecognizer(target: self, action: #selector(handleLyricsTap))
        lyricsContainerView.addGestureRecognizer(tapLyrics)
        nowPlayingContainer.addSubview(lyricsContainerView)

        lyricsSlotsContainer.backgroundColor = .clear
        lyricsSlotsContainer.translatesAutoresizingMaskIntoConstraints = false
        lyricsContainerView.addSubview(lyricsSlotsContainer)

        lyricStatusLabel.textAlignment = .center
        lyricStatusLabel.numberOfLines = 0
        lyricStatusLabel.lineBreakMode = .byWordWrapping
        lyricStatusLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
        lyricStatusLabel.isHidden = true
        lyricStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        lyricsSlotsContainer.addSubview(lyricStatusLabel)

        instrumentalSpinnerView.isHidden = true
        instrumentalSpinnerView.translatesAutoresizingMaskIntoConstraints = false
        lyricsSlotsContainer.addSubview(instrumentalSpinnerView)

        elapsedLabel.text = "0:00"
        elapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        elapsedLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(elapsedLabel)

        remainingLabel.text = "-0:00"
        remainingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        remainingLabel.textAlignment = .right
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(remainingLabel)

        volumeMuteIconView.image = makeVolumeMuteIcon(size: CGSize(width: 22, height: 14))
        volumeMuteIconView.contentMode = .scaleAspectFit
        volumeMuteIconView.isHidden = true
        volumeMuteIconView.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(volumeMuteIconView)

        volumeFullIconView.image = makeVolumeFullIcon(size: CGSize(width: 24, height: 14))
        volumeFullIconView.contentMode = .scaleAspectFit
        volumeFullIconView.isHidden = true
        volumeFullIconView.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(volumeFullIconView)

        sleepCountdownLabel.text = "0:00"
        sleepCountdownLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        sleepCountdownLabel.isHidden = true
        sleepCountdownLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(sleepCountdownLabel)

        sleepTargetLabel.text = "OFF"
        sleepTargetLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        sleepTargetLabel.textAlignment = .right
        sleepTargetLabel.adjustsFontSizeToFitWidth = true
        sleepTargetLabel.minimumScaleFactor = 0.8
        sleepTargetLabel.isHidden = true
        sleepTargetLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(sleepTargetLabel)

        progressTouchArea.backgroundColor = .clear
        progressTouchArea.isUserInteractionEnabled = true
        progressTouchArea.translatesAutoresizingMaskIntoConstraints = false
        let panSeek = UIPanGestureRecognizer(target: self, action: #selector(handleProgressScrub(_:)))
        progressTouchArea.addGestureRecognizer(panSeek)
        nowPlayingContainer.addSubview(progressTouchArea)

        progressTrack.layer.cornerRadius = 1.5
        progressTrack.isUserInteractionEnabled = false
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTouchArea.addSubview(progressTrack)

        progressFill.layer.cornerRadius = 1.5
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)
        progressWidthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)

        progressKnob.backgroundColor = .white
        progressKnob.layer.cornerRadius = 5.0
        progressKnob.layer.shadowColor = UIColor.black.cgColor
        progressKnob.layer.shadowOpacity = 0.35
        progressKnob.layer.shadowOffset = CGSize(width: 0, height: 1)
        progressKnob.layer.shadowRadius = 2
        progressKnob.isUserInteractionEnabled = false
        progressKnob.translatesAutoresizingMaskIntoConstraints = false
        progressTouchArea.addSubview(progressKnob)

        statusBannerContainer.layer.cornerRadius = 13
        statusBannerContainer.layer.borderWidth = 0.8
        statusBannerContainer.layer.shadowColor = UIColor.black.cgColor
        statusBannerContainer.layer.shadowRadius = 7
        statusBannerContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        statusBannerContainer.isUserInteractionEnabled = false
        statusBannerContainer.alpha = 0.0
        statusBannerContainer.transform = CGAffineTransform(translationX: 0, y: -10).scaledBy(x: 0.94, y: 0.94)
        statusBannerContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusBannerContainer)

        statusBannerAccentView.layer.cornerRadius = 3.0
        statusBannerAccentView.translatesAutoresizingMaskIntoConstraints = false
        statusBannerContainer.addSubview(statusBannerAccentView)

        statusBannerLabel.font = UIFont.systemFont(ofSize: 11.0, weight: .semibold)
        statusBannerLabel.textAlignment = .left
        statusBannerLabel.numberOfLines = 2
        statusBannerLabel.translatesAutoresizingMaskIntoConstraints = false
        statusBannerContainer.addSubview(statusBannerLabel)

        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let pctDouble = level >= 0 ? min(max(Double(level), 0.0), 1.0) : 0.85
        let pctInt = Int(round(pctDouble * 100.0))
        let innerFillWidth: CGFloat = pctDouble <= 0.0 ? 0.0 : max(1.5, 26.8 * CGFloat(pctDouble))
        batteryPercentLabel.text = "\(pctInt)"
        batteryWidthConstraint = batteryFill.widthAnchor.constraint(equalToConstant: innerFillWidth)

        titleNormalConstraints = [
            trackTitleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 14),
            trackTitleLabel.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -18),
            trackTitleLabel.bottomAnchor.constraint(equalTo: trackArtistLabel.topAnchor, constant: -4)
        ]

        titleLyricsConstraints = [
            trackTitleLabel.leadingAnchor.constraint(equalTo: artworkView.leadingAnchor, constant: 2),
            trackTitleLabel.trailingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: -2),
            trackTitleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 6),
            trackTitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: progressTouchArea.topAnchor, constant: -2)
        ]

        NSLayoutConstraint.activate([
            headerBar.topAnchor.constraint(equalTo: topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 28),

            headerTitleLabel.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 14),
            headerTitleLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            headerTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: clockLabel.leadingAnchor, constant: -6),

            clockLabel.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
            clockLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            clockLabel.widthAnchor.constraint(equalToConstant: 46),

            batteryCapView.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -12),
            batteryCapView.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            batteryCapView.widthAnchor.constraint(equalToConstant: 2.0),
            batteryCapView.heightAnchor.constraint(equalToConstant: 5.0),

            batteryView.trailingAnchor.constraint(equalTo: batteryCapView.leadingAnchor, constant: -1.5),
            batteryView.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            batteryView.widthAnchor.constraint(equalToConstant: 30),
            batteryView.heightAnchor.constraint(equalToConstant: 13),

            batteryFill.topAnchor.constraint(equalTo: batteryView.topAnchor, constant: 1.6),
            batteryFill.bottomAnchor.constraint(equalTo: batteryView.bottomAnchor, constant: -1.6),
            batteryFill.leadingAnchor.constraint(equalTo: batteryView.leadingAnchor, constant: 1.6),
            batteryWidthConstraint,

            batteryPercentLabel.topAnchor.constraint(equalTo: batteryView.topAnchor),
            batteryPercentLabel.bottomAnchor.constraint(equalTo: batteryView.bottomAnchor),
            batteryPercentLabel.leadingAnchor.constraint(equalTo: batteryView.leadingAnchor),
            batteryPercentLabel.trailingAnchor.constraint(equalTo: batteryView.trailingAnchor),

            playStateIcon.trailingAnchor.constraint(equalTo: batteryView.leadingAnchor, constant: -6),
            playStateIcon.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            playStateIcon.leadingAnchor.constraint(greaterThanOrEqualTo: clockLabel.trailingAnchor, constant: 4),

            coverLoadingStack.centerXAnchor.constraint(equalTo: coverFlowContainer.centerXAnchor),
            coverLoadingStack.centerYAnchor.constraint(equalTo: coverFlowContainer.centerYAnchor, constant: -6),

            tableView.topAnchor.constraint(equalTo: headerBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

            coverFlowContainer.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            coverFlowContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            coverFlowContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            coverFlowContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            coverCollectionView.topAnchor.constraint(equalTo: coverFlowContainer.topAnchor, constant: 4),
            coverCollectionView.leadingAnchor.constraint(equalTo: coverFlowContainer.leadingAnchor),
            coverCollectionView.trailingAnchor.constraint(equalTo: coverFlowContainer.trailingAnchor),
            coverCollectionView.bottomAnchor.constraint(equalTo: coverFlowContainer.bottomAnchor),

            bottomCaptionGuide.topAnchor.constraint(equalTo: coverFlowContainer.topAnchor, constant: 112),
            bottomCaptionGuide.bottomAnchor.constraint(equalTo: coverFlowContainer.bottomAnchor),
            bottomCaptionGuide.leadingAnchor.constraint(equalTo: coverFlowContainer.leadingAnchor, constant: 14),
            bottomCaptionGuide.trailingAnchor.constraint(equalTo: coverFlowContainer.trailingAnchor, constant: -14),

            coverCaptionStack.centerXAnchor.constraint(equalTo: bottomCaptionGuide.centerXAnchor),
            coverCaptionStack.centerYAnchor.constraint(equalTo: bottomCaptionGuide.centerYAnchor),
            coverCaptionStack.leadingAnchor.constraint(greaterThanOrEqualTo: bottomCaptionGuide.leadingAnchor),
            coverCaptionStack.trailingAnchor.constraint(lessThanOrEqualTo: bottomCaptionGuide.trailingAnchor),

            nowPlayingContainer.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            nowPlayingContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            nowPlayingContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            nowPlayingContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            artworkView.topAnchor.constraint(equalTo: nowPlayingContainer.topAnchor, constant: 12),
            artworkView.leadingAnchor.constraint(equalTo: nowPlayingContainer.leadingAnchor, constant: 18),
            artworkView.widthAnchor.constraint(equalToConstant: 124),
            artworkView.heightAnchor.constraint(equalToConstant: 124),

            artworkReflectionView.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 1),
            artworkReflectionView.centerXAnchor.constraint(equalTo: artworkView.centerXAnchor),
            artworkReflectionView.widthAnchor.constraint(equalToConstant: 124),
            artworkReflectionView.heightAnchor.constraint(equalToConstant: 46),

            trackArtistLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 14),
            trackArtistLabel.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -18),
            trackArtistLabel.bottomAnchor.constraint(equalTo: artworkView.centerYAnchor, constant: 18),

            trackIndexLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 14),
            trackIndexLabel.trailingAnchor.constraint(lessThanOrEqualTo: downloadStatusButton.leadingAnchor, constant: -6),
            trackIndexLabel.bottomAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: -2),

            downloadStatusButton.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -16),
            downloadStatusButton.centerYAnchor.constraint(equalTo: trackIndexLabel.centerYAnchor),
            downloadStatusButton.widthAnchor.constraint(equalToConstant: 26),
            downloadStatusButton.heightAnchor.constraint(equalToConstant: 26),

            lyricsContainerView.topAnchor.constraint(equalTo: artworkView.topAnchor),
            lyricsContainerView.bottomAnchor.constraint(equalTo: artworkView.bottomAnchor),
            lyricsContainerView.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 10),
            lyricsContainerView.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -12),

            lyricsSlotsContainer.topAnchor.constraint(equalTo: lyricsContainerView.topAnchor),
            lyricsSlotsContainer.bottomAnchor.constraint(equalTo: lyricsContainerView.bottomAnchor),
            lyricsSlotsContainer.leadingAnchor.constraint(equalTo: lyricsContainerView.leadingAnchor),
            lyricsSlotsContainer.trailingAnchor.constraint(equalTo: lyricsContainerView.trailingAnchor),

            lyricStatusLabel.leadingAnchor.constraint(equalTo: lyricsSlotsContainer.leadingAnchor, constant: 4),
            lyricStatusLabel.trailingAnchor.constraint(equalTo: lyricsSlotsContainer.trailingAnchor, constant: -4),
            lyricStatusLabel.centerYAnchor.constraint(equalTo: lyricsSlotsContainer.centerYAnchor),

            instrumentalSpinnerView.centerXAnchor.constraint(equalTo: lyricsSlotsContainer.centerXAnchor),
            instrumentalSpinnerView.centerYAnchor.constraint(equalTo: lyricsSlotsContainer.centerYAnchor),
            instrumentalSpinnerView.widthAnchor.constraint(equalToConstant: 24),
            instrumentalSpinnerView.heightAnchor.constraint(equalToConstant: 24),

            elapsedLabel.leadingAnchor.constraint(equalTo: nowPlayingContainer.leadingAnchor, constant: 18),
            elapsedLabel.bottomAnchor.constraint(equalTo: nowPlayingContainer.bottomAnchor, constant: -16),
            elapsedLabel.widthAnchor.constraint(equalToConstant: 36),

            remainingLabel.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -18),
            remainingLabel.centerYAnchor.constraint(equalTo: elapsedLabel.centerYAnchor),
            remainingLabel.widthAnchor.constraint(equalToConstant: 40),

            volumeMuteIconView.trailingAnchor.constraint(equalTo: elapsedLabel.trailingAnchor),
            volumeMuteIconView.centerYAnchor.constraint(equalTo: elapsedLabel.centerYAnchor),
            volumeMuteIconView.widthAnchor.constraint(equalToConstant: 22),
            volumeMuteIconView.heightAnchor.constraint(equalToConstant: 14),

            volumeFullIconView.leadingAnchor.constraint(equalTo: remainingLabel.leadingAnchor),
            volumeFullIconView.centerYAnchor.constraint(equalTo: remainingLabel.centerYAnchor),
            volumeFullIconView.widthAnchor.constraint(equalToConstant: 24),
            volumeFullIconView.heightAnchor.constraint(equalToConstant: 14),

            sleepCountdownLabel.leadingAnchor.constraint(equalTo: elapsedLabel.leadingAnchor),
            sleepCountdownLabel.trailingAnchor.constraint(equalTo: elapsedLabel.trailingAnchor),
            sleepCountdownLabel.centerYAnchor.constraint(equalTo: elapsedLabel.centerYAnchor),

            sleepTargetLabel.leadingAnchor.constraint(equalTo: remainingLabel.leadingAnchor),
            sleepTargetLabel.trailingAnchor.constraint(equalTo: remainingLabel.trailingAnchor),
            sleepTargetLabel.centerYAnchor.constraint(equalTo: remainingLabel.centerYAnchor),

            progressTouchArea.leadingAnchor.constraint(equalTo: nowPlayingContainer.leadingAnchor, constant: 66),
            progressTouchArea.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -66),
            progressTouchArea.centerYAnchor.constraint(equalTo: elapsedLabel.centerYAnchor),
            progressTouchArea.heightAnchor.constraint(equalToConstant: 24),

            progressTrack.leadingAnchor.constraint(equalTo: progressTouchArea.leadingAnchor),
            progressTrack.trailingAnchor.constraint(equalTo: progressTouchArea.trailingAnchor),
            progressTrack.centerYAnchor.constraint(equalTo: progressTouchArea.centerYAnchor),
            progressTrack.heightAnchor.constraint(equalToConstant: 2.5),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressWidthConstraint,

            progressKnob.centerYAnchor.constraint(equalTo: progressTrack.centerYAnchor),
            progressKnob.centerXAnchor.constraint(equalTo: progressFill.trailingAnchor),
            progressKnob.widthAnchor.constraint(equalToConstant: 10),
            progressKnob.heightAnchor.constraint(equalToConstant: 10),

            statusBannerContainer.topAnchor.constraint(equalTo: headerBar.bottomAnchor, constant: 8),
            statusBannerContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusBannerContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            statusBannerContainer.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            statusBannerAccentView.leadingAnchor.constraint(equalTo: statusBannerContainer.leadingAnchor, constant: 11),
            statusBannerAccentView.centerYAnchor.constraint(equalTo: statusBannerContainer.centerYAnchor),
            statusBannerAccentView.widthAnchor.constraint(equalToConstant: 6),
            statusBannerAccentView.heightAnchor.constraint(equalToConstant: 6),

            statusBannerLabel.leadingAnchor.constraint(equalTo: statusBannerAccentView.trailingAnchor, constant: 7),
            statusBannerLabel.trailingAnchor.constraint(equalTo: statusBannerContainer.trailingAnchor, constant: -12),
            statusBannerLabel.topAnchor.constraint(equalTo: statusBannerContainer.topAnchor, constant: 6.5),
            statusBannerLabel.bottomAnchor.constraint(equalTo: statusBannerContainer.bottomAnchor, constant: -6.5)
        ])
        NSLayoutConstraint.activate(titleNormalConstraints)
    }

    private func applyStatusBannerTheme() {
        let errorAccent = UIColor(red: 0.88, green: 0.28, blue: 0.28, alpha: 1.0)
        statusBannerAccentView.backgroundColor = statusBannerIsError ? errorAccent : theme.highlightTop
        statusBannerLabel.textColor = theme.primaryText

        switch theme {
        case .darkPod:
            statusBannerContainer.backgroundColor = UIColor(red: 0.13, green: 0.14, blue: 0.17, alpha: 0.94)
            statusBannerContainer.layer.borderColor = (statusBannerIsError
                ? errorAccent.withAlphaComponent(0.45)
                : UIColor(white: 1.0, alpha: 0.18)).cgColor
            statusBannerContainer.layer.shadowOpacity = 0.34
        case .sepiaPod:
            statusBannerContainer.backgroundColor = UIColor(red: 0.99, green: 0.96, blue: 0.90, alpha: 0.96)
            statusBannerContainer.layer.borderColor = (statusBannerIsError
                ? errorAccent.withAlphaComponent(0.38)
                : theme.highlightTop.withAlphaComponent(0.34)).cgColor
            statusBannerContainer.layer.shadowOpacity = 0.16
        case .classicBlue:
            statusBannerContainer.backgroundColor = UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 0.96)
            statusBannerContainer.layer.borderColor = (statusBannerIsError
                ? errorAccent.withAlphaComponent(0.38)
                : theme.highlightTop.withAlphaComponent(0.30)).cgColor
            statusBannerContainer.layer.shadowOpacity = 0.14
        }
    }

    func showStatusBanner(_ message: String) {
        statusBannerTimer?.invalidate()
        DispatchQueue.main.async {
            let lower = message.lowercased()
            self.statusBannerIsError = lower.contains("gagal")
                || lower.contains("tidak bisa")
                || lower.contains("tidak ada")
                || lower.contains("kosong")
                || lower.contains("belum ada")
                || lower.contains("error")

            self.statusBannerLabel.text = message
            self.applyStatusBannerTheme()
            self.bringSubviewToFront(self.statusBannerContainer)

            if self.statusBannerContainer.alpha < 0.1 {
                self.statusBannerContainer.transform = CGAffineTransform(translationX: 0, y: -10).scaledBy(x: 0.94, y: 0.94)
            }
            UIView.animate(
                withDuration: 0.34,
                delay: 0,
                usingSpringWithDamping: 0.84,
                initialSpringVelocity: 0.18,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                self.statusBannerContainer.alpha = 1.0
                self.statusBannerContainer.transform = .identity
            }

            let holdDuration: TimeInterval = self.statusBannerIsError ? 3.4 : 2.6
            self.statusBannerTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
                    self?.statusBannerContainer.alpha = 0.0
                    self?.statusBannerContainer.transform = CGAffineTransform(translationX: 0, y: -6).scaledBy(x: 0.96, y: 0.96)
                }
            }
        }
    }

    private func startClockTimer() {
        updateClockAndBattery()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateClockAndBattery()
        }
    }

    @objc private func handleBatteryLevelChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateClockAndBattery()
        }
    }

    private func updateClockAndBattery() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        clockLabel.text = formatter.string(from: Date())

        let level = UIDevice.current.batteryLevel
        let pctDouble = level >= 0 ? min(max(Double(level), 0.0), 1.0) : 0.85
        let pctInt = Int(round(pctDouble * 100.0))
        let innerFillWidth: CGFloat = pctDouble <= 0.0 ? 0.0 : max(1.5, 26.8 * CGFloat(pctDouble))
        batteryPercentLabel.text = "\(pctInt)"
        if abs(batteryWidthConstraint.constant - innerFillWidth) > 0.1 {
            batteryWidthConstraint.constant = innerFillWidth
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        headerSubtleTint.frame = headerBar.bounds
        artworkReflectionMask.frame = artworkReflectionView.bounds
        if let layout = coverCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let sideInset = max(0, (bounds.width - layout.itemSize.width) / 2.0)
            layout.sectionInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
        }
        applyCoverFlowTransforms()
        let curLyricsSize = lyricsContainerView.bounds.size
        if curLyricsSize.width > 20 && curLyricsSize.height > 20 && curLyricsSize != lastLyricsLayoutSize {
            lastLyricsLayoutSize = curLyricsSize
            if barMode == .lyrics && !nowPlayingContainer.isHidden {
                renderLyricSlots(animatedDirection: 0)
            }
        }
    }

    private func applyTheme() {
        backgroundColor = theme.screenBackground
        headerTitleLabel.textColor = theme.primaryText
        clockLabel.textColor = theme.primaryText

        if theme == .darkPod {
            headerSubtleTint.colors = [UIColor(white: 1.0, alpha: 0.06).cgColor, UIColor.clear.cgColor]
            playStateIcon.textColor = .white
            coverLoadingSpinner.color = .white
            batteryView.layer.borderColor = UIColor(white: 0.90, alpha: 1.0).cgColor
            batteryCapView.backgroundColor = UIColor(white: 0.90, alpha: 1.0)
            batteryFill.backgroundColor = UIColor(white: 0.42, alpha: 1.0)
            batteryPercentLabel.textColor = .white
        } else if theme == .classicBlue {
            headerSubtleTint.colors = [UIColor(white: 0.0, alpha: 0.05).cgColor, UIColor.clear.cgColor]
            playStateIcon.textColor = theme.primaryText
            coverLoadingSpinner.color = theme.primaryText
            batteryView.layer.borderColor = theme.primaryText.withAlphaComponent(0.65).cgColor
            batteryCapView.backgroundColor = theme.primaryText.withAlphaComponent(0.65)
            batteryFill.backgroundColor = UIColor(white: 0.76, alpha: 1.0)
            batteryPercentLabel.textColor = theme.primaryText
        } else {
            headerSubtleTint.colors = [UIColor(white: 0.0, alpha: 0.05).cgColor, UIColor.clear.cgColor]
            playStateIcon.textColor = theme.primaryText
            coverLoadingSpinner.color = theme.primaryText
            batteryView.layer.borderColor = theme.primaryText.withAlphaComponent(0.75).cgColor
            batteryCapView.backgroundColor = theme.primaryText.withAlphaComponent(0.75)
            batteryFill.backgroundColor = theme.highlightTop.withAlphaComponent(0.45)
            batteryPercentLabel.textColor = theme.primaryText
        }

        coverLoadingLabel.textColor = theme.secondaryText

        coverTitleLabel.textColor = theme.primaryText
        coverArtistLabel.textColor = theme.secondaryText
        trackIndexLabel.textColor = theme.secondaryText
        trackTitleLabel.textColor = theme.primaryText
        trackArtistLabel.textColor = theme.secondaryText
        elapsedLabel.textColor = theme.secondaryText
        remainingLabel.textColor = theme.secondaryText
        volumeMuteIconView.tintColor = theme.secondaryText
        volumeFullIconView.tintColor = theme.secondaryText
        sleepCountdownLabel.textColor = theme.secondaryText
        updateSleepTimerColors()
        progressTrack.backgroundColor = theme == .darkPod ? UIColor(white: 0.28, alpha: 1.0) : UIColor(white: 0.78, alpha: 1.0)
        progressFill.backgroundColor = theme == .darkPod ? .white : theme.highlightTop
        progressKnob.backgroundColor = theme == .darkPod ? .white : theme.highlightBottom
        tableView.reloadData()
        coverCollectionView.reloadData()
        downloadStatusButton.applyTheme(theme)
        applyStatusBannerTheme()
        lyricStyledActiveByIndex.removeAll()
        instrumentalSpinnerView.setColor(theme == .darkPod ? .white : theme.highlightBottom)
        renderLyricSlots(animatedDirection: 0)
    }

    // MARK: - Touchscreen Scrubbing
    @objc private func handleProgressScrub(_ gesture: UIPanGestureRecognizer) {
        let pt = gesture.location(in: progressTrack)
        let width = max(progressTrack.bounds.width, 1.0)
        let ratio = Double(min(max(pt.x / width, 0.0), 1.0))

        switch gesture.state {
        case .began, .changed:
            isScrubbing = true
            progressWidthConstraint.constant = CGFloat(ratio) * width
            onSeekRatioChanged?(ratio, false)
        case .ended, .cancelled:
            isScrubbing = false
            progressWidthConstraint.constant = CGFloat(ratio) * width
            onSeekRatioChanged?(ratio, true)
        default:
            break
        }
    }

    func updatePlayState(isPlaying: Bool) {
        playStateIcon.text = isPlaying ? "▶" : "❚❚"
        isPlaybackRunningForLyrics = isPlaying
        if isPlaying {
            lastLyricsSyncTimestamp = CACurrentMediaTime()
        }
        updateLyricsDisplayLinkState()
    }

    func showMenu(title: String, items: [IPodMenuRow], selectedIndex: Int = 0, isModernSettings: Bool = false, showStreamingRefresh: Bool = false) {
        stopSmoothScrollDisplayLink()
        coverLoadingSpinner.stopAnimating()
        coverLoadingStack.isHidden = true
        headerTitleLabel.text = title
        self.rows = items
        self.selectedIndex = min(max(0, selectedIndex), max(0, items.count - 1))
        self.isModernSettingsMenu = isModernSettings
        self.isCoverFlowActive = false
        self.isCoverFlowOffline = false
        tableView.rowHeight = 40
        nowPlayingContainer.isHidden = true
        updateLyricsDisplayLinkState()
        coverFlowContainer.isHidden = true
        tableView.isHidden = false
        tableView.reloadData()
        tableView.layoutIfNeeded()
        if !rows.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: self.selectedIndex, section: 0), at: .none, animated: false)
        }
    }

    private func currentCoverFlowCenterFrame() -> CGRect {
        let centerIndexPath = IndexPath(item: self.selectedIndex, section: 0)
        if let cell = coverCollectionView.cellForItem(at: centerIndexPath) as? IPodCoverFlowCell {
            return cell.coverImageView.convert(cell.coverImageView.bounds, to: self)
        }
        let targetCenterX = bounds.width / 2.0
        let targetTopY: CGFloat = 28.0 + 4.0 + 6.0
        return CGRect(x: targetCenterX - 50.0, y: targetTopY, width: 100.0, height: 100.0)
    }

    func showCoverFlowLoading(title: String) {
        stopSmoothScrollDisplayLink()
        headerTitleLabel.text = title
        coverTracks = []
        coverItems = []
        hasLeadingSearch = false
        selectedIndex = 0
        isCoverFlowActive = true
        isCoverFlowOffline = false

        nowPlayingContainer.isHidden = true
        updateLyricsDisplayLinkState()
        tableView.isHidden = true
        coverFlowContainer.isHidden = false
        coverFlowContainer.transform = .identity
        coverFlowContainer.alpha = 1.0

        coverCollectionView.alpha = 0.0
        coverCaptionStack.alpha = 0.0
        coverCollectionView.reloadData()

        coverLoadingLabel.text = "Memuat lagu..."
        coverLoadingStack.isHidden = false
        coverLoadingStack.alpha = 1.0
        coverLoadingSpinner.startAnimating()
    }

    func showCoverFlowNoInternet(title: String) {
        stopSmoothScrollDisplayLink()
        headerTitleLabel.text = title
        coverTracks = []
        coverItems = []
        hasLeadingSearch = false
        selectedIndex = 0
        isCoverFlowActive = true
        isCoverFlowOffline = true

        nowPlayingContainer.isHidden = true
        updateLyricsDisplayLinkState()
        tableView.isHidden = true
        coverFlowContainer.isHidden = false
        coverFlowContainer.transform = .identity
        coverFlowContainer.alpha = 1.0

        coverCollectionView.alpha = 0.0
        coverCaptionStack.alpha = 0.0
        coverCollectionView.reloadData()
        onActiveCoverImageChanged?(nil)

        coverLoadingSpinner.stopAnimating()
        coverLoadingLabel.numberOfLines = 0
        coverLoadingLabel.text = "Tidak ada koneksi internet"
        coverLoadingStack.isHidden = false
        coverLoadingStack.alpha = 1.0
    }

    func showSongsCoverFlow(
        title: String,
        tracks: [IPodTrack],
        selectedIndex: Int = 0,
        animateFromNowPlaying: Bool = false,
        showStreamingRefresh: Bool = false,
        searchQuery: String? = nil
    ) {
        stopSmoothScrollDisplayLink()
        let wasNowPlaying = !nowPlayingContainer.isHidden
        let wasLoading = !coverLoadingStack.isHidden
        let sourceArtworkFrame = artworkView.convert(artworkView.bounds, to: self)
        let sourceArtworkImage = artworkView.image

        headerTitleLabel.text = title
        self.coverTracks = tracks
        self.hasLeadingSearch = showStreamingRefresh
        self.activeSearchQuery = searchQuery
        self.isCoverFlowOffline = false
        if showStreamingRefresh {
            if tracks.isEmpty {
                self.coverItems = [.search, .refresh]
            } else {
                self.coverItems = [.search] + tracks.map { .track($0) } + [.refresh]
            }
        } else {
            self.coverItems = tracks.map { .track($0) }
        }

        self.selectedIndex = min(max(0, selectedIndex), max(0, coverItems.count - 1))
        self.isCoverFlowActive = true

        nowPlayingContainer.isHidden = true
        updateLyricsDisplayLinkState()
        tableView.isHidden = true
        coverFlowContainer.isHidden = false
        coverFlowContainer.transform = .identity
        coverFlowContainer.alpha = 1.0

        coverLoadingSpinner.stopAnimating()
        coverLoadingStack.isHidden = true

        setNeedsLayout()
        layoutIfNeeded()
        coverCollectionView.reloadData()
        coverCollectionView.layoutIfNeeded()

        let stepStride = coverItemWidth + coverItemSpacing
        targetCoverOffsetX = CGFloat(self.selectedIndex) * stepStride
        coverCollectionView.contentOffset = CGPoint(x: targetCoverOffsetX, y: 0)
        coverCollectionView.layoutIfNeeded()
        applyCoverFlowTransforms()

        if !coverItems.isEmpty {
            updateCoverFlowCaption(for: self.selectedIndex)
        } else {
            coverTitleLabel.text = "Tidak ada lagu"
            coverArtistLabel.text = "Sinkronkan lagu ke Music/Documents"
        }

        if wasLoading && !animateFromNowPlaying {
            coverCollectionView.alpha = 0.0
            coverCaptionStack.alpha = 0.0
            UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) {
                self.coverCollectionView.alpha = 1.0
                self.coverCaptionStack.alpha = 1.0
            }
            return
        }

        coverCollectionView.alpha = 1.0
        coverCaptionStack.alpha = 1.0

        if animateFromNowPlaying && wasNowPlaying && !coverItems.isEmpty {
            let exactTargetFrame = currentCoverFlowCenterFrame()

            let flyingCover = UIImageView(frame: sourceArtworkFrame)
            flyingCover.image = sourceArtworkImage ?? makeDefaultNoteArtwork()
            flyingCover.contentMode = .scaleAspectFill
            flyingCover.clipsToBounds = true
            flyingCover.layer.borderWidth = 0
            addSubview(flyingCover)

            let centerIndexPath = IndexPath(item: self.selectedIndex, section: 0)
            let centerCell = coverCollectionView.cellForItem(at: centerIndexPath)
            centerCell?.alpha = 0.0
            coverCollectionView.alpha = 0.0
            coverCaptionStack.alpha = 0.0

            UIView.animate(
                withDuration: 0.30,
                delay: 0,
                options: [.curveEaseOut],
                animations: {
                    flyingCover.frame = exactTargetFrame
                    self.coverCollectionView.alpha = 1.0
                    self.coverCaptionStack.alpha = 1.0
                },
                completion: { _ in
                    centerCell?.alpha = 1.0
                    flyingCover.removeFromSuperview()
                    self.applyCoverFlowTransforms()
                }
            )
        }
    }

    func updateCoverTrackArtwork(trackId: String, image: UIImage) {
        guard isCoverFlowActive else { return }
        if let tIdx = coverTracks.firstIndex(where: { $0.id == trackId }) {
            let old = coverTracks[tIdx]
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
            coverTracks[tIdx] = updated
            let itemIdx = tIdx + (hasLeadingSearch ? 1 : 0)
            if coverItems.indices.contains(itemIdx) {
                coverItems[itemIdx] = .track(updated)
                let ip = IndexPath(item: itemIdx, section: 0)
                if let cell = coverCollectionView.cellForItem(at: ip) as? IPodCoverFlowCell {
                    cell.configure(image: image)
                }
                if itemIdx == selectedIndex {
                    onActiveCoverImageChanged?(image)
                }
            }
        }
    }

    private func startSmoothScrollDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(stepSmoothCoverScroll))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopSmoothScrollDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func stepSmoothCoverScroll() {
        guard isCoverFlowActive else {
            stopSmoothScrollDisplayLink()
            return
        }
        let currentX = coverCollectionView.contentOffset.x
        let diff = targetCoverOffsetX - currentX
        if abs(diff) < 0.4 {
            coverCollectionView.contentOffset = CGPoint(x: targetCoverOffsetX, y: 0)
            applyCoverFlowTransforms()
            stopSmoothScrollDisplayLink()
            triggerCenterCoverSpringSettle()
        } else {
            coverCollectionView.contentOffset = CGPoint(x: currentX + diff * 0.36, y: 0)
            applyCoverFlowTransforms()
        }
    }

    private func triggerCenterCoverSpringSettle() {
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        guard let cell = coverCollectionView.cellForItem(at: indexPath) as? IPodCoverFlowCell else { return }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            cell.coverImageView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            cell.reflectionImageView.transform = CGAffineTransform(scaleX: 1.05, y: -1.05)
        }, completion: { _ in
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                usingSpringWithDamping: 0.65,
                initialSpringVelocity: 0.6,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    cell.coverImageView.transform = .identity
                    cell.reflectionImageView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
                }
            )
        })
    }

    func moveSelection(by delta: Int) {
        guard nowPlayingContainer.isHidden else { return }

        if isCoverFlowActive {
            guard !coverItems.isEmpty else { return }
            let next = min(max(0, selectedIndex + delta), coverItems.count - 1)
            if next != selectedIndex {
                selectedIndex = next
                let stepStride = coverItemWidth + coverItemSpacing
                targetCoverOffsetX = CGFloat(selectedIndex) * stepStride
                updateCoverFlowCaption(for: selectedIndex)
                startSmoothScrollDisplayLink()
            }
            return
        }

        guard !rows.isEmpty else { return }
        let next = min(max(0, selectedIndex + delta), rows.count - 1)
        if next != selectedIndex {
            selectedIndex = next
            tableView.reloadData()
            tableView.scrollToRow(at: IndexPath(row: selectedIndex, section: 0), at: .none, animated: false)
        }
    }

    private func updateCoverFlowCaption(for index: Int) {
        guard coverItems.indices.contains(index) else { return }
        switch coverItems[index] {
        case .track(let track):
            coverTitleLabel.text = track.title
            coverArtistLabel.text = track.artist
            onActiveCoverImageChanged?(track.artworkImage)
        case .search:
            if let q = activeSearchQuery, !q.isEmpty {
                coverTitleLabel.text = q
                coverArtistLabel.text = "Hasil pencarian"
            } else {
                coverTitleLabel.text = "Cari Lagu"
                coverArtistLabel.text = "Judul, artis, atau album"
            }
            onActiveCoverImageChanged?(nil)
        case .refresh:
            coverTitleLabel.text = "Refresh Lagu"
            coverArtistLabel.text = "Muat ulang daftar lagu baru"
            onActiveCoverImageChanged?(nil)
        }
    }

    private func applyCoverFlowTransforms() {
        guard isCoverFlowActive else { return }
        let centerX = coverCollectionView.contentOffset.x + coverCollectionView.bounds.width / 2.0
        let stepStride = coverItemWidth + coverItemSpacing

        for cell in coverCollectionView.visibleCells {
            let distance = cell.center.x - centerX
            let slotOffset = max(-3.6, min(3.6, distance / stepStride))
            let absSlot = abs(slotOffset)
            let sign: CGFloat = slotOffset >= 0 ? 1.0 : -1.0

            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 360.0

            let angle: CGFloat
            if absSlot < 0.20 {
                angle = -slotOffset * 2.2
            } else {
                angle = -sign * min(.pi / 2.35, 0.84 + (absSlot - 0.20) * 0.10)
            }

            let scale = max(0.76, 1.0 - (absSlot * 0.065))

            let pullIn: CGFloat
            if absSlot <= 1.0 {
                pullIn = sign * absSlot * 16.0
            } else {
                pullIn = sign * (16.0 + (absSlot - 1.0) * 6.5)
            }

            transform = CATransform3DTranslate(transform, pullIn, 0, -absSlot * 24.0)
            transform = CATransform3DRotate(transform, angle, 0, 1, 0)
            transform = CATransform3DScale(transform, scale, scale, 1.0)

            cell.layer.transform = transform
            cell.layer.zPosition = 200 - (absSlot * 30)
            cell.alpha = absSlot > 3.25 ? max(0, 1.0 - (absSlot - 3.25) * 2.5) : 1.0
        }
    }

    func updateNowPlayingTrackIndex(_ index: Int, total: Int) {
        trackIndexLabel.text = "\(index + 1) / \(total)"
    }

    func updateNowPlayingArtwork(_ image: UIImage) {
        artworkView.image = image
        artworkReflectionView.image = image
        onActiveCoverImageChanged?(image)
    }

    func showNowPlaying(track: IPodTrack, index: Int, total: Int, transitionDirection: Int = 0, animateFromCoverFlow: Bool = false) {
        let wasCoverFlow = isCoverFlowActive && !coverFlowContainer.isHidden
        let sourceCoverFrame = wasCoverFlow ? currentCoverFlowCenterFrame() : .zero

        stopSmoothScrollDisplayLink()
        coverLoadingSpinner.stopAnimating()
        coverLoadingStack.isHidden = true
        headerTitleLabel.text = headerTitle(for: barMode)
        tableView.isHidden = true
        coverFlowContainer.isHidden = true
        isCoverFlowActive = false
        isCoverFlowOffline = false
        nowPlayingContainer.isHidden = false

        trackTitleLabel.text = track.title
        trackArtistLabel.text = track.artist
        trackIndexLabel.text = "\(index + 1) of \(total)"

        let isLyricsMode = (barMode == .lyrics)
        applyLyricsLayout(active: isLyricsMode, animated: false)

        let nextImage = track.artworkImage ?? makeDefaultNoteArtwork()
        artworkView.image = nextImage
        artworkReflectionView.image = nextImage
        onActiveCoverImageChanged?(track.artworkImage)

        let targetReflectionAlpha: CGFloat = isLyricsMode ? 0.18 : 0.28

        if animateFromCoverFlow && wasCoverFlow {
            layoutIfNeeded()
            let exactTargetFrame = artworkView.convert(artworkView.bounds, to: self)

            let flyingCover = UIImageView(frame: sourceCoverFrame)
            flyingCover.image = nextImage
            flyingCover.contentMode = .scaleAspectFill
            flyingCover.clipsToBounds = true
            flyingCover.layer.borderWidth = 0
            addSubview(flyingCover)

            artworkView.alpha = 0.0
            artworkReflectionView.alpha = 0.0
            trackTitleLabel.alpha = 0.0
            trackIndexLabel.alpha = 0.0
            downloadStatusButton.alpha = 0.0
            trackArtistLabel.alpha = 0.0
            lyricsContainerView.alpha = 0.0
            progressTouchArea.alpha = 0.0
            elapsedLabel.alpha = 0.0
            remainingLabel.alpha = 0.0
            volumeMuteIconView.alpha = 0.0
            volumeFullIconView.alpha = 0.0
            sleepCountdownLabel.alpha = 0.0
            sleepTargetLabel.alpha = 0.0

            UIView.animate(
                withDuration: 0.30,
                delay: 0,
                options: [.curveEaseOut],
                animations: {
                    flyingCover.frame = exactTargetFrame
                    self.artworkReflectionView.alpha = targetReflectionAlpha
                    self.trackTitleLabel.alpha = 1.0
                    self.trackIndexLabel.alpha = isLyricsMode ? 0.0 : 1.0
                    self.downloadStatusButton.alpha = (isLyricsMode || !self.isCurrentTrackStreaming) ? 0.0 : 1.0
                    self.trackArtistLabel.alpha = isLyricsMode ? 0.0 : 1.0
                    self.lyricsContainerView.alpha = isLyricsMode ? 1.0 : 0.0
                    self.progressTouchArea.alpha = 1.0
                    self.elapsedLabel.alpha = 1.0
                    self.remainingLabel.alpha = 1.0
                    self.volumeMuteIconView.alpha = 1.0
                    self.volumeFullIconView.alpha = 1.0
                    self.sleepCountdownLabel.alpha = 1.0
                    self.sleepTargetLabel.alpha = 1.0
                },
                completion: { _ in
                    self.artworkView.alpha = 1.0
                    flyingCover.removeFromSuperview()
                }
            )
            lastDisplayedTrackId = track.id
            return
        }

        if transitionDirection != 0 && lastDisplayedTrackId != track.id {
            let dir: CGFloat = transitionDirection > 0 ? 1.0 : -1.0
            var startTransform = CATransform3DIdentity
            startTransform.m34 = -1.0 / 350.0
            startTransform = CATransform3DTranslate(startTransform, dir * 34.0, 0, -25.0)
            startTransform = CATransform3DRotate(startTransform, -dir * (.pi / 3.0), 0, 1, 0)
            startTransform = CATransform3DScale(startTransform, 0.84, 0.84, 1.0)

            artworkView.layer.transform = startTransform
            artworkView.alpha = 0.55
            artworkReflectionView.alpha = 0.0

            UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: [.curveEaseOut], animations: {
                self.artworkView.layer.transform = CATransform3DIdentity
                self.artworkView.alpha = 1.0
                self.artworkReflectionView.alpha = targetReflectionAlpha
            })
        } else {
            artworkView.layer.transform = CATransform3DIdentity
            artworkView.alpha = 1.0
            artworkReflectionView.alpha = targetReflectionAlpha
        }

        lastDisplayedTrackId = track.id
    }

    private func headerTitle(for mode: IPodNowPlayingBarMode) -> String {
        switch mode {
        case .duration:   return "Now Playing"
        case .volume:     return "Volume"
        case .lyrics:     return "Lyrics"
        case .sleepTimer: return "Sleep Time"
        }
    }

    func setNowPlayingBarMode(
        _ mode: IPodNowPlayingBarMode,
        volume: Float,
        sleepSetMinutes: Int,
        sleepElapsedSeconds: Int,
        isSleepActive: Bool
    ) {
        let wasLyrics = (barMode == .lyrics)
        let isLyrics = (mode == .lyrics)
        barMode = mode
        if !nowPlayingContainer.isHidden {
            headerTitleLabel.text = headerTitle(for: mode)
        }
        let showDurationBar = (mode == .duration || mode == .lyrics)
        elapsedLabel.isHidden = !showDurationBar
        remainingLabel.isHidden = !showDurationBar
        volumeMuteIconView.isHidden = (mode != .volume)
        volumeFullIconView.isHidden = (mode != .volume)
        sleepCountdownLabel.isHidden = (mode != .sleepTimer)
        sleepTargetLabel.isHidden = (mode != .sleepTimer)

        if wasLyrics != isLyrics {
            applyLyricsLayout(active: isLyrics, animated: !nowPlayingContainer.isHidden)
        }

        switch mode {
        case .duration:
            updateProgress(elapsed: lastElapsed, duration: lastDuration)
        case .volume:
            updateVolumeDisplay(volume)
        case .lyrics:
            updateProgress(elapsed: lastElapsed, duration: lastDuration)
            renderLyricSlots(animatedDirection: 0)
        case .sleepTimer:
            updateSleepTimerDisplay(
                setMinutes: sleepSetMinutes,
                elapsedSeconds: sleepElapsedSeconds,
                isActive: isSleepActive
            )
        }
        updateLyricsDisplayLinkState()
    }

    // MARK: - Lyrics Layout & Sync Engine
    private func applyLyricsLayout(active: Bool, animated: Bool) {
        nowPlayingContainer.bringSubviewToFront(trackTitleLabel)

        if animated {
            nowPlayingContainer.layoutIfNeeded()
        }

        if active {
            NSLayoutConstraint.deactivate(titleNormalConstraints)
            NSLayoutConstraint.activate(titleLyricsConstraints)
            trackTitleLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
            trackTitleLabel.textAlignment = .center
            trackTitleLabel.adjustsFontSizeToFitWidth = true
            trackTitleLabel.minimumScaleFactor = 0.85
            trackTitleLabel.layer.shadowColor = theme.screenBackground.cgColor
            trackTitleLabel.layer.shadowRadius = 3.0
            trackTitleLabel.layer.shadowOpacity = 0.85
            trackTitleLabel.layer.shadowOffset = .zero
        } else {
            NSLayoutConstraint.deactivate(titleLyricsConstraints)
            NSLayoutConstraint.activate(titleNormalConstraints)
            trackTitleLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
            trackTitleLabel.textAlignment = .left
            trackTitleLabel.adjustsFontSizeToFitWidth = false
            trackTitleLabel.layer.shadowOpacity = 0.0
        }

        if animated {
            if active {
                lyricsContainerView.isHidden = false
                lyricsContainerView.alpha = 0.0
                lyricsContainerView.transform = CGAffineTransform(translationX: 0, y: 10)
                renderLyricSlots(animatedDirection: 0)

                UIView.animate(
                    withDuration: 0.58,
                    delay: 0,
                    usingSpringWithDamping: 0.94,
                    initialSpringVelocity: 0.12,
                    options: [.curveEaseInOut, .beginFromCurrentState],
                    animations: {
                        self.nowPlayingContainer.layoutIfNeeded()
                        self.trackArtistLabel.alpha = 0.0
                        self.trackArtistLabel.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                        self.trackIndexLabel.alpha = 0.0
                        self.downloadStatusButton.alpha = 0.0
                        self.artworkReflectionView.alpha = 0.18
                        self.lyricsContainerView.alpha = 1.0
                        self.lyricsContainerView.transform = .identity
                    },
                    completion: { _ in
                        if self.barMode == .lyrics {
                            self.trackArtistLabel.isHidden = true
                            self.trackIndexLabel.isHidden = true
                            self.downloadStatusButton.isHidden = true
                        }
                    }
                )
            } else {
                trackArtistLabel.isHidden = false
                trackIndexLabel.isHidden = false
                downloadStatusButton.isHidden = !isCurrentTrackStreaming
                trackArtistLabel.alpha = 0.0
                trackArtistLabel.transform = CGAffineTransform(translationX: 0, y: 4).scaledBy(x: 0.92, y: 0.92)
                trackIndexLabel.alpha = 0.0
                downloadStatusButton.alpha = 0.0

                UIView.animate(
                    withDuration: 0.58,
                    delay: 0,
                    usingSpringWithDamping: 0.94,
                    initialSpringVelocity: 0.12,
                    options: [.curveEaseInOut, .beginFromCurrentState],
                    animations: {
                        self.nowPlayingContainer.layoutIfNeeded()
                        self.artworkReflectionView.alpha = 0.28
                        self.lyricsContainerView.alpha = 0.0
                        self.lyricsContainerView.transform = CGAffineTransform(translationX: 0, y: 8)
                    },
                    completion: { _ in
                        if self.barMode != .lyrics {
                            self.lyricsContainerView.isHidden = true
                            self.lyricsContainerView.transform = .identity
                        }
                    }
                )

                UIView.animate(
                    withDuration: 0.45,
                    delay: 0.18,
                    options: [.curveEaseOut, .beginFromCurrentState],
                    animations: {
                        self.trackArtistLabel.alpha = 1.0
                        self.trackArtistLabel.transform = .identity
                        self.trackIndexLabel.alpha = 1.0
                        self.downloadStatusButton.alpha = self.isCurrentTrackStreaming ? 1.0 : 0.0
                    }
                )
            }
        } else {
            trackArtistLabel.isHidden = active
            trackArtistLabel.alpha = active ? 0.0 : 1.0
            trackArtistLabel.transform = .identity
            trackIndexLabel.isHidden = active
            trackIndexLabel.alpha = active ? 0.0 : 1.0
            downloadStatusButton.isHidden = active || !isCurrentTrackStreaming
            downloadStatusButton.alpha = (active || !isCurrentTrackStreaming) ? 0.0 : 1.0
            artworkReflectionView.alpha = active ? 0.18 : 0.28
            lyricsContainerView.isHidden = !active
            lyricsContainerView.alpha = active ? 1.0 : 0.0
            lyricsContainerView.transform = .identity
            if active {
                renderLyricSlots(animatedDirection: 0)
            }
            nowPlayingContainer.layoutIfNeeded()
        }
    }

    func setLyricsLoading(for trackId: String) {
        currentLyrics = nil
        lyricDisplayItems.removeAll()
        cachedDisplayHeights.removeAll()
        lyricsLoadingTrackId = trackId
        lyricsUnavailableTrackId = nil
        activeDisplayIndex = nil
        displayLyricCenterIndex = 0
        visualLyricPos = 0
        targetLyricPos = 0
        lyricAnimDuration = 0
        isLyricsAutoScroll = true
        updateLyricsDisplayLinkState()
        renderLyricSlots(animatedDirection: 0)
    }

    func applyLyrics(_ lyrics: IPodTrackLyrics?, for trackId: String, currentElapsed: TimeInterval) {
        if lyricsLoadingTrackId == trackId {
            lyricsLoadingTrackId = nil
        }
        clearLyricPoolLabels(animated: false)
        lastLyricsSyncElapsed = currentElapsed
        lastLyricsSyncTimestamp = CACurrentMediaTime()

        guard let lyrics = lyrics, !lyrics.lines.isEmpty else {
            currentLyrics = nil
            lyricDisplayItems.removeAll()
            cachedDisplayHeights.removeAll()
            lyricsUnavailableTrackId = trackId
            activeDisplayIndex = nil
            displayLyricCenterIndex = 0
            visualLyricPos = 0
            targetLyricPos = 0
            lyricAnimDuration = 0
            isLyricsAutoScroll = true
            updateLyricsDisplayLinkState()
            renderLyricSlots(animatedDirection: 0)
            return
        }

        lyricsUnavailableTrackId = nil
        currentLyrics = lyrics
        rebuildLyricDisplayItems()
        isLyricsAutoScroll = true
        activeDisplayIndex = computeActiveDisplayIndex(for: currentElapsed)
        displayLyricCenterIndex = activeDisplayIndex ?? 0
        visualLyricPos = CGFloat(displayLyricCenterIndex)
        targetLyricPos = visualLyricPos
        lyricAnimDuration = 0
        updateLyricsDisplayLinkState()
        renderLyricSlots(animatedDirection: 0)
    }

    func scrollLyrics(by steps: Int) {
        guard !lyricDisplayItems.isEmpty else { return }
        let oldCenter = displayLyricCenterIndex
        let newCenter = min(max(0, oldCenter + steps), lyricDisplayItems.count - 1)
        guard newCenter != oldCenter else { return }

        displayLyricCenterIndex = newCenter
        if currentLyrics?.isSynced == true {
            isLyricsAutoScroll = (activeDisplayIndex != nil && newCenter == activeDisplayIndex!)
        } else {
            isLyricsAutoScroll = false
        }

        isManualFastScrolling = true
        lyricAnimStartPos = visualLyricPos
        targetLyricPos = CGFloat(newCenter)
        lyricAnimStartTime = CACurrentMediaTime()
        lyricAnimDuration = 0.16
        updateLyricsDisplayLinkState()
        layoutLyricItemsFrame(at: visualLyricPos, smoothElapsed: currentSmoothLyricsElapsed())
    }

    @objc private func handleLyricsTap() {
        guard barMode == .lyrics,
              !nowPlayingContainer.isHidden,
              let lyrics = currentLyrics,
              lyrics.isSynced,
              !lyricDisplayItems.isEmpty else { return }

        let smoothElapsed = currentSmoothLyricsElapsed()
        let targetIndex = min(max(0, activeDisplayIndex ?? computeActiveDisplayIndex(for: smoothElapsed) ?? 0), lyricDisplayItems.count - 1)
        let targetPos = CGFloat(targetIndex)
        let dist = abs(targetPos - visualLyricPos)
        guard !isLyricsAutoScroll || displayLyricCenterIndex != targetIndex || dist > 0.05 else { return }

        isLyricsAutoScroll = true
        isManualFastScrolling = false
        displayLyricCenterIndex = targetIndex
        lyricAnimStartPos = visualLyricPos
        targetLyricPos = targetPos
        lyricAnimStartTime = CACurrentMediaTime()
        // Travel smoothly across however many lines the user scrolled forward/backward
        lyricAnimDuration = min(1.30, max(0.46, 0.40 + Double(dist) * 0.036))
        updateLyricsDisplayLinkState()
        layoutLyricItemsFrame(at: visualLyricPos, smoothElapsed: smoothElapsed)
    }

    private func isAnimatingLyricPosition() -> Bool {
        return lyricAnimDuration > 0 && abs(targetLyricPos - visualLyricPos) > 0.0005
    }

    private func updateLyricsDisplayLinkState() {
        let canDisplayLyrics = (barMode == .lyrics) && !nowPlayingContainer.isHidden
        let needsSyncTick = isPlaybackRunningForLyrics && (currentLyrics?.isSynced == true) && !lyricDisplayItems.isEmpty
        let needsScrollTick = !lyricDisplayItems.isEmpty && isAnimatingLyricPosition()
        let shouldRun = canDisplayLyrics && (needsSyncTick || needsScrollTick)

        if shouldRun {
            if lyricsDisplayLink == nil {
                let link = CADisplayLink(target: self, selector: #selector(stepLyricsDisplayLink))
                link.preferredFramesPerSecond = 60
                link.add(to: .main, forMode: .common)
                lyricsDisplayLink = link
            }
        } else {
            lyricsDisplayLink?.invalidate()
            lyricsDisplayLink = nil
        }
    }

    @objc private func stepLyricsDisplayLink() {
        guard barMode == .lyrics, !nowPlayingContainer.isHidden else {
            updateLyricsDisplayLinkState()
            return
        }

        let now = CACurrentMediaTime()
        let smoothElapsed = currentSmoothLyricsElapsed()
        if isPlaybackRunningForLyrics && currentLyrics?.isSynced == true {
            updateLyricsPlaybackTime(smoothElapsed)
        }

        if lyricAnimDuration > 0 && abs(targetLyricPos - visualLyricPos) > 0.0005 {
            let rawT = min(max((now - lyricAnimStartTime) / lyricAnimDuration, 0.0), 1.0)
            let eased: Double
            if isManualFastScrolling {
                eased = 1.0 - pow(1.0 - rawT, 2.2)
            } else {
                eased = rawT < 0.5
                    ? 4.0 * rawT * rawT * rawT
                    : 1.0 - pow(-2.0 * rawT + 2.0, 3.0) / 2.0
            }
            visualLyricPos = lyricAnimStartPos + (targetLyricPos - lyricAnimStartPos) * CGFloat(eased)
            if rawT >= 1.0 {
                visualLyricPos = targetLyricPos
                lyricAnimDuration = 0
                isManualFastScrolling = false
            }
        } else {
            visualLyricPos = targetLyricPos
            lyricAnimDuration = 0
            isManualFastScrolling = false
        }

        layoutLyricItemsFrame(at: visualLyricPos, smoothElapsed: smoothElapsed)

        if !isAnimatingLyricPosition() && !(isPlaybackRunningForLyrics && currentLyrics?.isSynced == true) {
            updateLyricsDisplayLinkState()
        }
    }

    private func currentSmoothLyricsElapsed() -> TimeInterval {
        if isPlaybackRunningForLyrics {
            return lastLyricsSyncElapsed + (CACurrentMediaTime() - lastLyricsSyncTimestamp)
        }
        return lastLyricsSyncElapsed
    }

    private func isInstrumentalLineText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return true }
        let markers: Set<String> = [
            "♪", "♫", "🎵", "🎶", "...", "..", "~", "—", "-", "•", "•••",
            "instrumental", "(instrumental)", "[instrumental]", "music", "(music)", "[music]"
        ]
        return markers.contains(trimmed)
    }

    private func estimatedVocalWindow(for text: String) -> TimeInterval {
        let words = Double(max(1, text.split(separator: " ").count))
        let chars = Double(text.count)
        return min(11.0, max(5.5, words * 0.65 + chars * 0.08 + 2.2))
    }

    private func rebuildLyricDisplayItems() {
        lyricDisplayItems.removeAll()
        cachedDisplayHeights.removeAll()
        guard let lyrics = currentLyrics, !lyrics.lines.isEmpty else { return }

        if !lyrics.isSynced {
            for (i, line) in lyrics.lines.enumerated() {
                lyricDisplayItems.append(.line(lineIndex: i, text: line.text, startTime: nil))
            }
            return
        }

        if let firstT = lyrics.lines.first?.time, firstT >= 3.0 {
            lyricDisplayItems.append(.instrumental(
                startTime: 0.0,
                endTime: max(0.5, firstT - 0.15),
                isIntro: true
            ))
        }

        for (i, line) in lyrics.lines.enumerated() {
            let start = line.time ?? 0
            let nextT = lyrics.lines.indices.contains(i + 1) ? (lyrics.lines[i + 1].time ?? max(start + 1.0, lastDuration)) : max(start + 1.0, lastDuration)
            if isInstrumentalLineText(line.text) && (nextT - 0.15 - start) >= 4.0 {
                lyricDisplayItems.append(.instrumental(
                    startTime: start,
                    endTime: max(start + 0.5, nextT - 0.15),
                    isIntro: false
                ))
                continue
            }

            lyricDisplayItems.append(.line(lineIndex: i, text: line.text, startTime: line.time))

            // Embed mid-song instrumental loader inline so it glides into view instead of popping in abruptly
            if lyrics.lines.indices.contains(i + 1),
               let lineStart = line.time,
               let upcomingT = lyrics.lines[i + 1].time,
               upcomingT - lineStart >= 18.0 {
                let estimatedSing = estimatedVocalWindow(for: line.text)
                let gapStart = lineStart + estimatedSing + 1.2
                let gapEnd = upcomingT - 0.15
                if gapEnd - gapStart >= 6.0 {
                    lyricDisplayItems.append(.instrumental(
                        startTime: gapStart,
                        endTime: gapEnd,
                        isIntro: false
                    ))
                }
            }
        }
    }

    private func computeActiveDisplayIndex(for elapsed: TimeInterval) -> Int? {
        guard let lyrics = currentLyrics, lyrics.isSynced, !lyricDisplayItems.isEmpty else { return nil }
        let leadTarget = elapsed + 0.15
        var matched: Int?
        for (idx, item) in lyricDisplayItems.enumerated() {
            switch item {
            case .line(_, _, let start?):
                if start <= leadTarget {
                    matched = idx
                } else {
                    return matched
                }
            case .line(_, _, nil):
                break
            case .instrumental(let s, let e, let isIntro):
                if isIntro {
                    if elapsed < e {
                        return idx
                    }
                    matched = idx
                } else {
                    if elapsed >= s && elapsed < e {
                        return idx
                    } else if s > elapsed {
                        return matched
                    }
                    matched = idx
                }
            }
        }
        return matched
    }

    private func updateLyricsPlaybackTime(_ elapsed: TimeInterval) {
        guard let lyrics = currentLyrics, lyrics.isSynced, !lyricDisplayItems.isEmpty else { return }
        let newActive = computeActiveDisplayIndex(for: elapsed)
        guard newActive != activeDisplayIndex else { return }

        activeDisplayIndex = newActive

        if !isLyricsAutoScroll {
            if let act = newActive, act == displayLyricCenterIndex {
                isLyricsAutoScroll = true
            }
            return
        }

        if let act = newActive, act != displayLyricCenterIndex {
            displayLyricCenterIndex = act
            isManualFastScrolling = false
            if barMode == .lyrics && !nowPlayingContainer.isHidden {
                lyricAnimStartPos = visualLyricPos
                targetLyricPos = CGFloat(act)
                lyricAnimStartTime = CACurrentMediaTime()
                lyricAnimDuration = 0.56
                updateLyricsDisplayLinkState()
            } else {
                visualLyricPos = CGFloat(act)
                targetLyricPos = visualLyricPos
                lyricAnimDuration = 0
            }
        }
    }

    private func karaokeProgress(forDisplayIndex displayIndex: Int, elapsed: TimeInterval) -> Double {
        guard let lyrics = currentLyrics, lyrics.isSynced,
              lyricDisplayItems.indices.contains(displayIndex),
              case .line(let origIdx, let lineText, let start?) = lyricDisplayItems[displayIndex] else {
            return 1.0
        }

        let words = Double(max(1, lineText.split(separator: " ").count))
        let chars = Double(lineText.count)
        let slowVocalCap = max(4.2, words * 0.54 + chars * 0.045 + 1.10)

        let singingWindow: TimeInterval
        if lyrics.lines.indices.contains(origIdx + 1), let nextT = lyrics.lines[origIdx + 1].time {
            let gap = max(0.45, nextT - start)
            if gap >= 18.0 {
                // Mid-song break follows: finish singing highlight ahead of the inline loader
                singingWindow = min(9.0, slowVocalCap)
            } else if gap <= 4.5 {
                singingWindow = max(0.42, gap * 0.84)
            } else {
                // Keep slow lines responsive without stretching across trailing silence/breaths
                let slowBudget = min(9.0, slowVocalCap + min(1.4, (gap - 4.5) * 0.20))
                singingWindow = min(gap * 0.80, slowBudget)
            }
        } else {
            let remaining = max(1.0, lastDuration - start)
            let slowBudget = min(9.0, slowVocalCap + min(1.4, max(0.0, remaining - 4.5) * 0.20))
            singingWindow = min(remaining * 0.82, slowBudget)
        }
        let linear = min(max((elapsed + 0.12 - start) / max(0.4, singingWindow), 0.0), 1.0)
        return pow(linear, 0.91)
    }

    private func interpolateColor(from c1: UIColor, to c2: UIColor, t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 1
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 1
        if !c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) {
            var w: CGFloat = 0
            c1.getWhite(&w, alpha: &a1)
            r1 = w; g1 = w; b1 = w
        }
        if !c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) {
            var w: CGFloat = 0
            c2.getWhite(&w, alpha: &a2)
            r2 = w; g2 = w; b2 = w
        }
        let clamped = min(max(t, 0.0), 1.0)
        return UIColor(
            red: r1 + (r2 - r1) * clamped,
            green: g1 + (g2 - g1) * clamped,
            blue: b1 + (b2 - b1) * clamped,
            alpha: a1 + (a2 - a1) * clamped
        )
    }

    private func lyricBaseFont() -> UIFont {
        return UIFont.systemFont(ofSize: 13.0, weight: .bold)
    }

    private func lyricParagraphStyle(for font: UIFont) -> NSParagraphStyle {
        let fixedLineHeight = ceil(font.lineHeight + 3.5)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.minimumLineHeight = fixedLineHeight
        paragraph.maximumLineHeight = fixedLineHeight
        paragraph.lineSpacing = 0
        return paragraph
    }

    private func measureLyricLabelHeight(text: String, width: CGFloat) -> CGFloat {
        let font = lyricBaseFont()
        let paragraph = lyricParagraphStyle(for: font)
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .paragraphStyle: paragraph
            ],
            context: nil
        )
        return max(ceil(font.lineHeight + 3.5), ceil(rect.height))
    }

    private func buildStaticLyricAttributedText(text: String, color: UIColor) -> NSAttributedString {
        let font = lyricBaseFont()
        let paragraph = lyricParagraphStyle(for: font)
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func buildKaraokeAttributedText(
        text: String,
        litColor: UIColor,
        dimmedColor: UIColor,
        progress: Double
    ) -> NSAttributedString {
        let font = lyricBaseFont()
        let paragraph = lyricParagraphStyle(for: font)

        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: dimmedColor,
                .paragraphStyle: paragraph
            ]
        )

        let nsStr = text as NSString
        var ranges: [NSRange] = []
        var pos = 0
        while pos < nsStr.length {
            let r = nsStr.rangeOfComposedCharacterSequence(at: pos)
            ranges.append(r)
            pos = r.location + r.length
        }
        guard !ranges.isEmpty else { return attr }

        let clampedProg = min(max(progress, 0.0), 1.0)

        // Compute vocal-weighted character timeline so vowels/syllables pace naturally instead of rushing early words
        let vowels = Set<Character>(["a", "e", "i", "o", "u", "y"])
        var cumWeights: [Double] = []
        cumWeights.reserveCapacity(ranges.count)
        var running = 0.0
        for r in ranges {
            let token = nsStr.substring(with: r).lowercased()
            let ch = token.first ?? " "
            let w: Double
            if ch.isWhitespace {
                w = 0.25
            } else if ch == "," || ch == ";" || ch == "—" || ch == "…" {
                w = 1.25
            } else if vowels.contains(ch) {
                w = 1.28
            } else if ch.isLetter {
                w = 0.85
            } else {
                w = 0.45
            }
            running += w
            cumWeights.append(running)
        }

        let targetWeight = (-0.15 + (Double(ranges.count) + 1.15) * clampedProg) * (running / Double(ranges.count))
        var cursor = -0.15 + (Double(ranges.count) + 1.15) * clampedProg
        if running > 0 {
            var mappedIdx = Double(ranges.count)
            for (idx, cw) in cumWeights.enumerated() {
                let prev = idx > 0 ? cumWeights[idx - 1] : 0.0
                if targetWeight <= cw {
                    let frac = (cw > prev) ? (targetWeight - prev) / (cw - prev) : 0.0
                    mappedIdx = Double(idx) + frac
                    break
                }
            }
            if targetWeight < 0 {
                mappedIdx = targetWeight / max(0.25, cumWeights.first ?? 1.0)
            } else if targetWeight > running {
                mappedIdx = Double(ranges.count) + (targetWeight - running) / max(0.25, (running / Double(ranges.count)))
            }
            cursor = mappedIdx
        }

        for (i, range) in ranges.enumerated() {
            let rawT = (cursor - Double(i)) / 2.2 + 0.5
            let t = CGFloat(min(max(rawT, 0.0), 1.0))
            let color = interpolateColor(from: dimmedColor, to: litColor, t: t)
            attr.addAttribute(.foregroundColor, value: color, range: range)

            // Smooth cosine micro-wave only around the active cursor; passed words settle at baseline 0
            if clampedProg > 0.01 && clampedProg < 0.985 {
                let dist = abs(cursor - Double(i))
                if dist < 3.0 {
                    let lift = CGFloat(0.5 * (1.0 + cos(Double.pi * dist / 3.0)) * 1.15)
                    attr.addAttribute(.baselineOffset, value: lift, range: range)
                }
            }
        }
        return attr
    }

    private func makePoolLyricLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.font = lyricBaseFont()
        label.layer.contentsScale = UIScreen.main.scale
        return label
    }

    private func clearLyricPoolLabels(animated: Bool) {
        let existing = lyricLabelsByIndex
        lyricLabelsByIndex.removeAll()
        lyricStyledActiveByIndex.removeAll()
        for (_, label) in existing {
            if animated {
                UIView.animate(withDuration: 0.2, animations: {
                    label.alpha = 0.0
                }, completion: { _ in
                    label.removeFromSuperview()
                })
            } else {
                label.removeFromSuperview()
            }
        }
    }

    private func ensureCachedDisplayHeights(for contentW: CGFloat) {
        if abs(cachedMeasureWidth - contentW) > 0.5 || cachedDisplayHeights.count != lyricDisplayItems.count {
            cachedMeasureWidth = contentW
            cachedDisplayHeights = lyricDisplayItems.map { item in
                switch item {
                case .line(_, let text, _):
                    return measureLyricLabelHeight(text: text, width: contentW)
                case .instrumental:
                    return 34.0
                }
            }
        }
    }

    private func anchorYPositions(forAnchor anchorIdx: Int, minIdx: Int, maxIdx: Int, containerH: CGFloat) -> [Int: CGFloat] {
        var result: [Int: CGFloat] = [:]
        guard lyricDisplayItems.indices.contains(anchorIdx) else { return result }
        let slotGap: CGFloat = 10.0

        func anchorScale(offset d: Int) -> CGFloat {
            let ad = abs(d)
            if ad == 0 { return 1.0 }
            if ad == 1 { return 0.76 }
            return 0.62
        }

        func itemHeight(_ i: Int) -> CGFloat {
            return cachedDisplayHeights.indices.contains(i) ? cachedDisplayHeights[i] : 22.0
        }

        result[anchorIdx] = containerH / 2.0

        if anchorIdx - 1 >= minIdx {
            for k in stride(from: anchorIdx - 1, through: minIdx, by: -1) {
                let below = k + 1
                let belowY = result[below] ?? (containerH / 2.0)
                let belowH = itemHeight(below) * anchorScale(offset: below - anchorIdx)
                let curH = itemHeight(k) * anchorScale(offset: k - anchorIdx)
                result[k] = belowY - belowH / 2.0 - slotGap - curH / 2.0
            }
        }

        if anchorIdx + 1 <= maxIdx {
            for k in (anchorIdx + 1)...maxIdx {
                let above = k - 1
                let aboveY = result[above] ?? (containerH / 2.0)
                let aboveH = itemHeight(above) * anchorScale(offset: above - anchorIdx)
                let curH = itemHeight(k) * anchorScale(offset: k - anchorIdx)
                result[k] = aboveY + aboveH / 2.0 + slotGap + curH / 2.0
            }
        }

        return result
    }

    private func renderLyricSlots(animatedDirection: Int) {
        let smoothElapsed = currentSmoothLyricsElapsed()
        guard !lyricDisplayItems.isEmpty else {
            layoutLyricItemsFrame(at: 0, smoothElapsed: smoothElapsed)
            return
        }

        if animatedDirection != 0 && barMode == .lyrics && !nowPlayingContainer.isHidden {
            lyricAnimStartPos = visualLyricPos
            targetLyricPos = CGFloat(min(max(0, displayLyricCenterIndex), lyricDisplayItems.count - 1))
            lyricAnimStartTime = CACurrentMediaTime()
            if !isManualFastScrolling && lyricAnimDuration <= 0 {
                lyricAnimDuration = 0.56
            }
            updateLyricsDisplayLinkState()
        } else {
            visualLyricPos = CGFloat(min(max(0, displayLyricCenterIndex), lyricDisplayItems.count - 1))
            targetLyricPos = visualLyricPos
            lyricAnimDuration = 0
            isManualFastScrolling = false
        }

        layoutLyricItemsFrame(at: visualLyricPos, smoothElapsed: smoothElapsed)
    }

    private func layoutLyricItemsFrame(at pos: CGFloat, smoothElapsed: TimeInterval) {
        guard !lyricDisplayItems.isEmpty else {
            clearLyricPoolLabels(animated: false)
            instrumentalSpinnerView.isHidden = true
            instrumentalSpinnerView.setProgress(0.0)
            instrumentalSpinnerView.transform = .identity
            instrumentalSpinnerView.alpha = 1.0

            lyricStatusLabel.isHidden = false
            lyricStatusLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
            lyricStatusLabel.textColor = theme.secondaryText.withAlphaComponent(0.75)
            lyricStatusLabel.text = lyricsLoadingTrackId != nil ? "Mencari lirik..." : "Lirik tidak tersedia"
            return
        }

        lyricStatusLabel.isHidden = true
        let containerW = lyricsContainerView.bounds.width
        let containerH = lyricsContainerView.bounds.height
        guard containerW > 20 && containerH > 20 else { return }

        let contentW = max(60.0, containerW - 4.0)
        let centerX = containerW / 2.0
        ensureCachedDisplayHeights(for: contentW)

        let count = lyricDisplayItems.count
        let clampedPos = min(max(pos, 0.0), CGFloat(count - 1))
        let p0 = min(max(0, Int(floor(clampedPos))), count - 1)
        let p1 = min(count - 1, p0 + 1)
        let frac = clampedPos - CGFloat(p0)

        let minVis = max(0, p0 - 3)
        let maxVis = min(count - 1, p1 + 3)

        let yMap0 = anchorYPositions(forAnchor: p0, minIdx: minVis, maxIdx: maxVis, containerH: containerH)
        let yMap1 = (p1 == p0) ? yMap0 : anchorYPositions(forAnchor: p1, minIdx: minVis, maxIdx: maxVis, containerH: containerH)

        let existingKeys = Array(lyricLabelsByIndex.keys)
        for idx in existingKeys where idx < minVis || idx > maxVis {
            lyricLabelsByIndex.removeValue(forKey: idx)?.removeFromSuperview()
            lyricStyledActiveByIndex.removeValue(forKey: idx)
        }

        let isSynced = (currentLyrics?.isSynced == true)
        let litColor = theme == .darkPod ? UIColor.white : theme.highlightBottom
        let dimmedColor = (theme == .darkPod ? UIColor.white : theme.primaryText).withAlphaComponent(0.36)
        let glowColor = (theme == .darkPod ? UIColor.white : theme.highlightTop).cgColor
        let baseGlow: Float = theme == .darkPod ? 0.80 : 0.48
        let staticColor = isSynced
            ? theme.secondaryText.withAlphaComponent(0.76)
            : theme.primaryText.withAlphaComponent(0.88)

        var chosenSpinnerState: (dist: CGFloat, y: CGFloat, scale: CGFloat, alpha: CGFloat, progress: CGFloat)?

        for idx in minVis...maxVis {
            let y0 = yMap0[idx] ?? (containerH / 2.0)
            let y1 = yMap1[idx] ?? (containerH / 2.0)
            let y = (1.0 - frac) * y0 + frac * y1
            let dist = abs(CGFloat(idx) - clampedPos)
            let scale: CGFloat = dist <= 1.0 ? (1.0 - (1.0 - 0.76) * dist) : max(0.62, 0.76 - 0.14 * (dist - 1.0))

            let baseAlpha: CGFloat
            if dist <= 1.0 {
                baseAlpha = 1.0 - (1.0 - 0.72) * dist
            } else if dist < 2.2 {
                baseAlpha = max(0.0, 0.72 * (1.0 - (dist - 1.0) / 1.2))
            } else {
                baseAlpha = 0.0
            }

            switch lyricDisplayItems[idx] {
            case .instrumental(let startTime, let endTime, _):
                lyricLabelsByIndex.removeValue(forKey: idx)?.removeFromSuperview()
                lyricStyledActiveByIndex.removeValue(forKey: idx)

                let prog: Double
                if smoothElapsed >= endTime {
                    prog = 1.0
                } else if smoothElapsed <= startTime {
                    prog = 0.0
                } else {
                    prog = min(max((smoothElapsed - startTime) / max(0.5, endTime - startTime), 0.0), 1.0)
                }

                // Keep inline loader visible in bottom (upcoming), center (active), and top (completed) slots
                let instAlpha: CGFloat = (activeDisplayIndex == idx) ? baseAlpha : (baseAlpha * 0.78)

                if instAlpha > 0.01 {
                    if chosenSpinnerState == nil || dist < chosenSpinnerState!.dist {
                        chosenSpinnerState = (dist, y, scale, instAlpha, CGFloat(prog))
                    }
                }

            case .line(_, let text, _):
                let label: UILabel
                if let existing = lyricLabelsByIndex[idx] {
                    label = existing
                } else {
                    let created = makePoolLyricLabel()
                    lyricsSlotsContainer.addSubview(created)
                    lyricLabelsByIndex[idx] = created
                    label = created
                }

                let h = cachedDisplayHeights.indices.contains(idx) ? cachedDisplayHeights[idx] : 22.0
                let targetSize = CGSize(width: contentW, height: h)
                if label.bounds.size != targetSize {
                    label.bounds = CGRect(origin: .zero, size: targetSize)
                }

                let isSongActiveLine = isSynced && (activeDisplayIndex == idx)
                if isSongActiveLine {
                    let prog = karaokeProgress(forDisplayIndex: idx, elapsed: smoothElapsed)
                    label.attributedText = buildKaraokeAttributedText(
                        text: text,
                        litColor: litColor,
                        dimmedColor: dimmedColor,
                        progress: prog
                    )
                    label.layer.shadowColor = glowColor
                    label.layer.shadowRadius = dist < 0.5 ? 6.0 : 5.0
                    label.layer.shadowOffset = .zero
                    label.layer.shadowOpacity = baseGlow * max(0.0, 1.0 - Float(dist) * 0.85)
                    lyricStyledActiveByIndex[idx] = true
                } else {
                    if lyricStyledActiveByIndex[idx] != false {
                        label.attributedText = buildStaticLyricAttributedText(text: text, color: staticColor)
                        label.layer.shadowOpacity = 0.0
                        lyricStyledActiveByIndex[idx] = false
                    }
                }

                label.center = CGPoint(x: centerX, y: y)
                label.transform = CGAffineTransform(scaleX: scale, y: scale)
                label.alpha = baseAlpha
            }
        }

        if let spinner = chosenSpinnerState {
            instrumentalSpinnerView.setColor(theme == .darkPod ? .white : theme.highlightBottom)
            instrumentalSpinnerView.setProgress(spinner.progress)
            instrumentalSpinnerView.center = CGPoint(x: centerX, y: spinner.y)
            instrumentalSpinnerView.transform = CGAffineTransform(scaleX: spinner.scale, y: spinner.scale)
            instrumentalSpinnerView.alpha = spinner.alpha
            instrumentalSpinnerView.isHidden = false
        } else {
            instrumentalSpinnerView.isHidden = true
            instrumentalSpinnerView.setProgress(0.0)
            instrumentalSpinnerView.transform = .identity
            instrumentalSpinnerView.alpha = 1.0
        }
    }

    func updateNowPlayingDownloadState(_ state: IPodTrackDownloadState?, isStreamingTrack: Bool) {
        isCurrentTrackStreaming = isStreamingTrack
        if !isStreamingTrack {
            downloadStatusButton.isHidden = true
            downloadStatusButton.alpha = 0.0
            return
        }
        downloadStatusButton.applyTheme(theme)
        downloadStatusButton.setState(state ?? .notDownloaded)
        let shouldHide = (barMode == .lyrics)
        downloadStatusButton.isHidden = shouldHide
        downloadStatusButton.alpha = shouldHide ? 0.0 : 1.0
    }

    @objc private func handleDownloadButtonTap() {
        onDownloadButtonTapped?()
    }

    @objc private func handleArtworkDoubleTap() {
        guard !nowPlayingContainer.isHidden else { return }
        onArtworkDoubleTapped?()
    }

    func updateVolumeDisplay(_ volume: Float) {
        currentVolumeLevel = min(max(volume, 0.0), 1.0)
        guard barMode == .volume, !isScrubbing else { return }
        layoutIfNeeded()
        progressWidthConstraint.constant = progressTrack.bounds.width * CGFloat(currentVolumeLevel)
    }

    func updateSleepTimerDisplay(setMinutes: Int, elapsedSeconds: Int, isActive: Bool) {
        let wasActive = lastSleepActive
        lastSleepSetMinutes = setMinutes
        lastSleepElapsedSeconds = elapsedSeconds
        lastSleepActive = isActive

        let totalSec = max(0, setMinutes * 60)
        let displayElapsed = isActive ? min(max(0, elapsedSeconds), totalSec) : 0
        sleepCountdownLabel.text = formatTime(TimeInterval(displayElapsed))
        if isActive && setMinutes > 0 {
            let remaining = max(0, totalSec - displayElapsed)
            sleepTargetLabel.text = "-\(formatTime(TimeInterval(remaining)))"
        } else {
            sleepTargetLabel.text = setMinutes > 0 ? formatTime(TimeInterval(totalSec)) : "OFF"
        }
        updateSleepTimerColors()

        guard barMode == .sleepTimer, !isScrubbing else { return }
        layoutIfNeeded()
        let ratio: CGFloat
        if isActive && setMinutes > 0 {
            let totalSec = Double(setMinutes * 60)
            ratio = CGFloat(min(max(Double(displayElapsed) / totalSec, 0.0), 1.0))
        } else {
            ratio = CGFloat(min(max(Double(setMinutes) / 60.0, 0.0), 1.0))
        }
        let targetWidth = progressTrack.bounds.width * ratio
        if !wasActive && isActive && displayElapsed == 0 {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
                self.progressWidthConstraint.constant = targetWidth
                self.progressTouchArea.layoutIfNeeded()
            }
        } else {
            progressWidthConstraint.constant = targetWidth
        }
    }

    private func updateSleepTimerColors() {
        let activeColor = lastSleepActive ? theme.highlightTop : (lastSleepSetMinutes > 0 ? theme.primaryText : theme.secondaryText)
        sleepTargetLabel.textColor = activeColor
    }

    func updateProgress(elapsed: TimeInterval, duration: TimeInterval, fromScrub: Bool = false) {
        let safeDur = max(duration, 1.0)
        lastElapsed = elapsed
        lastDuration = safeDur
        lastLyricsSyncElapsed = elapsed
        lastLyricsSyncTimestamp = CACurrentMediaTime()
        updateLyricsPlaybackTime(elapsed)
        if barMode == .lyrics && !nowPlayingContainer.isHidden {
            layoutLyricItemsFrame(at: visualLyricPos, smoothElapsed: elapsed)
        }
        if barMode != .duration && barMode != .lyrics { return }
        if isScrubbing && !fromScrub { return }
        if !fromScrub {
            let ratio = CGFloat(min(max(elapsed / safeDur, 0.0), 1.0))
            progressWidthConstraint.constant = progressTrack.bounds.width * ratio
        }
        elapsedLabel.text = formatTime(elapsed)
        remainingLabel.text = "-\(formatTime(max(0, safeDur - elapsed)))"
    }

    private func makeVolumeMuteIcon(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // Speaker cone
        ctx.setFillColor(UIColor.white.cgColor)
        let speaker = UIBezierPath()
        speaker.move(to: CGPoint(x: 2, y: 5))
        speaker.addLine(to: CGPoint(x: 5.5, y: 5))
        speaker.addLine(to: CGPoint(x: 10, y: 1.5))
        speaker.addLine(to: CGPoint(x: 10, y: 12.5))
        speaker.addLine(to: CGPoint(x: 5.5, y: 9))
        speaker.addLine(to: CGPoint(x: 2, y: 9))
        speaker.close()
        speaker.fill()

        // Mute "x"
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.8)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 13.5, y: 4.5))
        ctx.addLine(to: CGPoint(x: 18.5, y: 9.5))
        ctx.move(to: CGPoint(x: 18.5, y: 4.5))
        ctx.addLine(to: CGPoint(x: 13.5, y: 9.5))
        ctx.strokePath()

        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
    }

    private func makeVolumeFullIcon(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // Speaker cone
        ctx.setFillColor(UIColor.white.cgColor)
        let speaker = UIBezierPath()
        speaker.move(to: CGPoint(x: 1.5, y: 5))
        speaker.addLine(to: CGPoint(x: 4.8, y: 5))
        speaker.addLine(to: CGPoint(x: 9, y: 1.5))
        speaker.addLine(to: CGPoint(x: 9, y: 12.5))
        speaker.addLine(to: CGPoint(x: 4.8, y: 9))
        speaker.addLine(to: CGPoint(x: 1.5, y: 9))
        speaker.close()
        speaker.fill()

        // 3 sound wave arcs
        UIColor.white.setStroke()
        let waveCenter = CGPoint(x: 9.2, y: size.height / 2.0)
        for r in [CGFloat(3.4), CGFloat(6.2), CGFloat(9.0)] {
            let arc = UIBezierPath(
                arcCenter: waveCenter,
                radius: r,
                startAngle: -.pi * 0.34,
                endAngle: .pi * 0.34,
                clockwise: true
            )
            arc.lineWidth = 1.6
            arc.lineCapStyle = .round
            arc.stroke()
        }

        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func makeDefaultNoteArtwork() -> UIImage? {
        let size = CGSize(width: 240, height: 240)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        theme.highlightTop.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 78, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let str = "♫"
        let strSize = str.size(withAttributes: attrs)
        str.draw(at: CGPoint(x: (size.width - strSize.width) / 2, y: (size.height - strSize.height) / 2), withAttributes: attrs)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "IPodCell", for: indexPath) as! IPodMenuCell
        cell.configure(row: rows[indexPath.row], isSelected: indexPath.row == selectedIndex, isModernSettings: isModernSettingsMenu, theme: theme)
        return cell
    }

    private func makeSearchCoverImage() -> UIImage? {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        let glyphColor: UIColor = theme == .darkPod
            ? UIColor(white: 0.92, alpha: 1.0)
            : theme.primaryText

        let lensCenter = CGPoint(x: 45.0, y: 45.0)
        let lensRadius: CGFloat = 15.0
        let lensPath = UIBezierPath(
            arcCenter: lensCenter,
            radius: lensRadius,
            startAngle: 0,
            endAngle: .pi * 2.0,
            clockwise: true
        )
        lensPath.lineWidth = 3.6
        glyphColor.setStroke()
        lensPath.stroke()

        let handlePath = UIBezierPath()
        let angle: CGFloat = .pi * 0.25
        handlePath.move(to: CGPoint(
            x: lensCenter.x + lensRadius * cos(angle),
            y: lensCenter.y + lensRadius * sin(angle)
        ))
        handlePath.addLine(to: CGPoint(x: 68.0, y: 68.0))
        handlePath.lineWidth = 4.2
        handlePath.lineCapStyle = .round
        handlePath.stroke()

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func makeRefreshCoverImage() -> UIImage? {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        let glyphColor: UIColor = theme == .darkPod
            ? UIColor(white: 0.92, alpha: 1.0)
            : theme.primaryText

        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let radius: CGFloat = 18.0
        let startAngle: CGFloat = -.pi * 0.25
        let endAngle: CGFloat = .pi * 1.45

        let arcPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        arcPath.lineWidth = 3.6
        arcPath.lineCapStyle = .round
        glyphColor.setStroke()
        arcPath.stroke()

        // Arrowhead pointing clockwise at endAngle
        let tipX = center.x + radius * cos(endAngle)
        let tipY = center.y + radius * sin(endAngle)
        let tangentAngle = endAngle + .pi / 2.0
        let headLen: CGFloat = 9.0
        let wingAngle: CGFloat = .pi * 0.78

        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: tipX + 2.8 * cos(tangentAngle), y: tipY + 2.8 * sin(tangentAngle)))
        arrowPath.addLine(to: CGPoint(x: tipX + headLen * cos(tangentAngle + wingAngle), y: tipY + headLen * sin(tangentAngle + wingAngle)))
        arrowPath.addLine(to: CGPoint(x: tipX + headLen * cos(tangentAngle - wingAngle), y: tipY + headLen * sin(tangentAngle - wingAngle)))
        arrowPath.close()
        glyphColor.setFill()
        arrowPath.fill()

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - UICollectionViewDataSource & Delegate (Cover Flow)
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return coverItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CoverCell", for: indexPath) as! IPodCoverFlowCell
        switch coverItems[indexPath.item] {
        case .track(let track):
            cell.configure(image: track.artworkImage ?? makeDefaultNoteArtwork(), showReflection: true)
        case .search:
            cell.configure(image: makeSearchCoverImage(), showReflection: false)
        case .refresh:
            cell.configure(image: makeRefreshCoverImage(), showReflection: false)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        applyCoverFlowTransforms()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == selectedIndex {
            guard coverItems.indices.contains(indexPath.item) else { return }
            switch coverItems[indexPath.item] {
            case .search:
                onStreamingSearchTapped?()
            case .refresh:
                onStreamingRefreshTapped?()
            case .track:
                let trackIdx = indexPath.item - (hasLeadingSearch ? 1 : 0)
                if coverTracks.indices.contains(trackIdx) {
                    onCoverFlowTrackSelected?(trackIdx)
                }
            }
        } else {
            selectedIndex = indexPath.item
            let stepStride = coverItemWidth + coverItemSpacing
            targetCoverOffsetX = CGFloat(selectedIndex) * stepStride
            updateCoverFlowCaption(for: selectedIndex)
            startSmoothScrollDisplayLink()
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView === coverCollectionView {
            stopSmoothScrollDisplayLink()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === coverCollectionView else { return }
        applyCoverFlowTransforms()

        let stepStride = coverItemWidth + coverItemSpacing
        let rawIndex = Int(round(coverCollectionView.contentOffset.x / stepStride))
        let clamped = min(max(0, rawIndex), max(0, coverItems.count - 1))
        if clamped != selectedIndex {
            selectedIndex = clamped
            updateCoverFlowCaption(for: selectedIndex)
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView === coverCollectionView else { return }
        let stepStride = coverItemWidth + coverItemSpacing
        let rawIndex = Int(round(targetContentOffset.pointee.x / stepStride))
        let clamped = min(max(0, rawIndex), max(0, coverItems.count - 1))
        targetCoverOffsetX = CGFloat(clamped) * stepStride
        targetContentOffset.pointee.x = targetCoverOffsetX
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView === coverCollectionView {
            triggerCenterCoverSpringSettle()
        }
    }
}