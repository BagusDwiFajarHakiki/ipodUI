import UIKit

enum IPodNowPlayingBarMode {
    case duration
    case volume
    case lyrics
    case sleepTimer
}

enum IPodColorTheme: CaseIterable {
    case darkPod
    case sepiaPod
    case classicBlue

    var displayName: String {
        switch self {
        case .darkPod:     return "Dark"
        case .sepiaPod:    return "SepiaPod"
        case .classicBlue: return "Classic Blue"
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
        highlightGradient.frame = cardBackground.bounds
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

class IPodScreenView: UIView, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var theme: IPodColorTheme = .darkPod {
        didSet { applyTheme() }
    }

    var onCoverFlowTrackSelected: ((Int) -> Void)?
    var onSeekRatioChanged: ((Double, Bool) -> Void)?
    var onActiveCoverImageChanged: ((UIImage?) -> Void)?
    var onStreamingRefreshTapped: (() -> Void)?
    var onStreamingSearchTapped: (() -> Void)?

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

    // Banner Status Error
    private let statusBannerLabel = UILabel()
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
    private let lyricsContainerView = UIView()
    private let lyricsSlotsContainer = UIView()
    private let lyricPrevLabel = UILabel()
    private let lyricCurrentLabel = UILabel()
    private let lyricNextLabel = UILabel()
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
    private var currentLyrics: IPodTrackLyrics?
    private var lyricsLoadingTrackId: String?
    private var lyricsUnavailableTrackId: String?
    private var activeLyricIndex: Int?
    private var displayLyricCenterIndex: Int = 0
    private var isLyricsAutoScroll: Bool = true
    private weak var activeLyricSnapshot: UIView?
    private var isPlaybackRunningForLyrics: Bool = false
    private var lastLyricsSyncElapsed: TimeInterval = 0
    private var lastLyricsSyncTimestamp: CFTimeInterval = CACurrentMediaTime()
    private var lyricsDisplayLink: CADisplayLink?
    private var lastBouncedLineIndex: Int?

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
        tableView.rowHeight = 36
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
        artworkView.translatesAutoresizingMaskIntoConstraints = false
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

        lyricsContainerView.clipsToBounds = true
        lyricsContainerView.isHidden = true
        lyricsContainerView.alpha = 0.0
        lyricsContainerView.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(lyricsContainerView)

        lyricsSlotsContainer.backgroundColor = .clear
        lyricsSlotsContainer.translatesAutoresizingMaskIntoConstraints = false
        lyricsContainerView.addSubview(lyricsSlotsContainer)

        for lbl in [lyricPrevLabel, lyricCurrentLabel, lyricNextLabel] {
            lbl.textAlignment = .center
            lbl.numberOfLines = 0
            lbl.lineBreakMode = .byWordWrapping
            lbl.translatesAutoresizingMaskIntoConstraints = false
            lyricsSlotsContainer.addSubview(lbl)
        }
        lyricCurrentLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        lyricPrevLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        lyricNextLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

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

        statusBannerLabel.font = UIFont.systemFont(ofSize: 10.5, weight: .bold)
        statusBannerLabel.textColor = .white
        statusBannerLabel.backgroundColor = UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 0.92)
        statusBannerLabel.textAlignment = .center
        statusBannerLabel.layer.cornerRadius = 5
        statusBannerLabel.clipsToBounds = true
        statusBannerLabel.numberOfLines = 2
        statusBannerLabel.alpha = 0.0
        statusBannerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusBannerLabel)

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
            trackIndexLabel.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -18),
            trackIndexLabel.bottomAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: -2),

            lyricsContainerView.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: -2),
            lyricsContainerView.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 10),
            lyricsContainerView.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -12),
            lyricsContainerView.bottomAnchor.constraint(equalTo: progressTouchArea.topAnchor, constant: -4),

            lyricsSlotsContainer.topAnchor.constraint(equalTo: lyricsContainerView.topAnchor),
            lyricsSlotsContainer.bottomAnchor.constraint(equalTo: lyricsContainerView.bottomAnchor),
            lyricsSlotsContainer.leadingAnchor.constraint(equalTo: lyricsContainerView.leadingAnchor),
            lyricsSlotsContainer.trailingAnchor.constraint(equalTo: lyricsContainerView.trailingAnchor),

            lyricCurrentLabel.leadingAnchor.constraint(equalTo: lyricsSlotsContainer.leadingAnchor, constant: 2),
            lyricCurrentLabel.trailingAnchor.constraint(equalTo: lyricsSlotsContainer.trailingAnchor, constant: -2),
            lyricCurrentLabel.centerYAnchor.constraint(equalTo: lyricsSlotsContainer.centerYAnchor),

            lyricPrevLabel.leadingAnchor.constraint(equalTo: lyricsSlotsContainer.leadingAnchor, constant: 2),
            lyricPrevLabel.trailingAnchor.constraint(equalTo: lyricsSlotsContainer.trailingAnchor, constant: -2),
            lyricPrevLabel.bottomAnchor.constraint(equalTo: lyricCurrentLabel.topAnchor, constant: -10),

            lyricNextLabel.leadingAnchor.constraint(equalTo: lyricsSlotsContainer.leadingAnchor, constant: 2),
            lyricNextLabel.trailingAnchor.constraint(equalTo: lyricsSlotsContainer.trailingAnchor, constant: -2),
            lyricNextLabel.topAnchor.constraint(equalTo: lyricCurrentLabel.bottomAnchor, constant: 10),

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

            statusBannerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusBannerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusBannerLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        NSLayoutConstraint.activate(titleNormalConstraints)
    }

    func showStatusBanner(_ message: String) {
        statusBannerTimer?.invalidate()
        DispatchQueue.main.async {
            self.statusBannerLabel.text = message
            UIView.animate(withDuration: 0.2) {
                self.statusBannerLabel.alpha = 1.0
            }
            self.statusBannerTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.25) {
                    self?.statusBannerLabel.alpha = 0.0
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
        tableView.rowHeight = isModernSettings ? 40 : 34
        nowPlayingContainer.isHidden = true
        updateLyricsDisplayLinkState()
        coverFlowContainer.isHidden = true
        tableView.isHidden = false
        tableView.reloadData()
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

        nowPlayingContainer.isHidden = true
        updateLyricsDisplayLinkState()
        tableView.isHidden = true
        coverFlowContainer.isHidden = false
        coverFlowContainer.transform = .identity
        coverFlowContainer.alpha = 1.0

        coverCollectionView.alpha = 0.0
        coverCaptionStack.alpha = 0.0
        coverCollectionView.reloadData()

        coverLoadingStack.isHidden = false
        coverLoadingStack.alpha = 1.0
        coverLoadingSpinner.startAnimating()
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
        nowPlayingContainer.isHidden = false

        trackTitleLabel.text = track.title
        trackArtistLabel.text = track.artist
        trackIndexLabel.text = "\(index + 1) / \(total)"

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
                    withDuration: 0.34,
                    delay: 0,
                    usingSpringWithDamping: 0.86,
                    initialSpringVelocity: 0.25,
                    options: [.curveEaseOut, .beginFromCurrentState],
                    animations: {
                        self.nowPlayingContainer.layoutIfNeeded()
                        self.trackArtistLabel.alpha = 0.0
                        self.trackArtistLabel.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                        self.trackIndexLabel.alpha = 0.0
                        self.artworkReflectionView.alpha = 0.18
                        self.lyricsContainerView.alpha = 1.0
                        self.lyricsContainerView.transform = .identity
                    },
                    completion: { _ in
                        if self.barMode == .lyrics {
                            self.trackArtistLabel.isHidden = true
                            self.trackIndexLabel.isHidden = true
                        }
                    }
                )
            } else {
                trackArtistLabel.isHidden = false
                trackIndexLabel.isHidden = false
                trackArtistLabel.alpha = 0.0
                trackArtistLabel.transform = CGAffineTransform(translationX: 0, y: 4).scaledBy(x: 0.92, y: 0.92)
                trackIndexLabel.alpha = 0.0

                UIView.animate(
                    withDuration: 0.34,
                    delay: 0,
                    usingSpringWithDamping: 0.86,
                    initialSpringVelocity: 0.25,
                    options: [.curveEaseOut, .beginFromCurrentState],
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
                    withDuration: 0.36,
                    delay: 0.10,
                    options: [.curveEaseOut, .beginFromCurrentState],
                    animations: {
                        self.trackArtistLabel.alpha = 1.0
                        self.trackArtistLabel.transform = .identity
                        self.trackIndexLabel.alpha = 1.0
                    }
                )
            }
        } else {
            trackArtistLabel.isHidden = active
            trackArtistLabel.alpha = active ? 0.0 : 1.0
            trackArtistLabel.transform = .identity
            trackIndexLabel.isHidden = active
            trackIndexLabel.alpha = active ? 0.0 : 1.0
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
        lyricsLoadingTrackId = trackId
        lyricsUnavailableTrackId = nil
        activeLyricIndex = nil
        lastBouncedLineIndex = nil
        displayLyricCenterIndex = 0
        isLyricsAutoScroll = true
        updateLyricsDisplayLinkState()
        renderLyricSlots(animatedDirection: 0)
    }

    func applyLyrics(_ lyrics: IPodTrackLyrics?, for trackId: String, currentElapsed: TimeInterval) {
        if lyricsLoadingTrackId == trackId {
            lyricsLoadingTrackId = nil
        }
        lastLyricsSyncElapsed = currentElapsed
        lastLyricsSyncTimestamp = CACurrentMediaTime()

        guard let lyrics = lyrics, !lyrics.lines.isEmpty else {
            currentLyrics = nil
            lyricsUnavailableTrackId = trackId
            activeLyricIndex = nil
            lastBouncedLineIndex = nil
            displayLyricCenterIndex = 0
            isLyricsAutoScroll = true
            updateLyricsDisplayLinkState()
            renderLyricSlots(animatedDirection: 0)
            return
        }

        lyricsUnavailableTrackId = nil
        currentLyrics = lyrics
        isLyricsAutoScroll = true
        lastBouncedLineIndex = nil
        activeLyricIndex = computeActiveLyricIndex(for: currentElapsed)
        displayLyricCenterIndex = activeLyricIndex ?? 0
        updateLyricsDisplayLinkState()
        renderLyricSlots(animatedDirection: 0)
    }

    func scrollLyrics(by steps: Int) {
        guard let lyrics = currentLyrics, !lyrics.lines.isEmpty else { return }
        let oldCenter = displayLyricCenterIndex
        let newCenter = min(max(0, oldCenter + steps), lyrics.lines.count - 1)
        guard newCenter != oldCenter else { return }

        displayLyricCenterIndex = newCenter
        if lyrics.isSynced {
            isLyricsAutoScroll = (activeLyricIndex != nil && newCenter == activeLyricIndex!)
        } else {
            isLyricsAutoScroll = false
        }

        renderLyricSlots(animatedDirection: newCenter > oldCenter ? 1 : -1)
    }

    private func updateLyricsDisplayLinkState() {
        let shouldRun = (barMode == .lyrics)
            && !nowPlayingContainer.isHidden
            && isPlaybackRunningForLyrics
            && (currentLyrics?.isSynced == true)

        if shouldRun {
            if lyricsDisplayLink == nil {
                let link = CADisplayLink(target: self, selector: #selector(stepLyricsDisplayLink))
                link.preferredFramesPerSecond = 30
                link.add(to: .main, forMode: .common)
                lyricsDisplayLink = link
            }
        } else {
            lyricsDisplayLink?.invalidate()
            lyricsDisplayLink = nil
        }
    }

    @objc private func stepLyricsDisplayLink() {
        guard barMode == .lyrics, !nowPlayingContainer.isHidden, isPlaybackRunningForLyrics else {
            updateLyricsDisplayLinkState()
            return
        }
        let smoothElapsed = lastLyricsSyncElapsed + (CACurrentMediaTime() - lastLyricsSyncTimestamp)
        updateLyricsPlaybackTime(smoothElapsed)
        updateActiveLyricReadingEffect(elapsed: smoothElapsed)
    }

    private func currentSmoothLyricsElapsed() -> TimeInterval {
        if isPlaybackRunningForLyrics {
            return lastLyricsSyncElapsed + (CACurrentMediaTime() - lastLyricsSyncTimestamp)
        }
        return lastLyricsSyncElapsed
    }

    private func updateLyricsPlaybackTime(_ elapsed: TimeInterval) {
        guard let lyrics = currentLyrics, lyrics.isSynced, !lyrics.lines.isEmpty else { return }
        let newActive = computeActiveLyricIndex(for: elapsed)
        guard newActive != activeLyricIndex else { return }

        activeLyricIndex = newActive

        if !isLyricsAutoScroll {
            if let act = newActive, act == displayLyricCenterIndex {
                // Playback caught up to user's manual scroll position -> resume auto-scroll
                isLyricsAutoScroll = true
            }
            // Do not move displayLyricCenterIndex; only refresh highlight on the active song line
            renderLyricSlots(animatedDirection: 0)
            return
        }

        if let act = newActive, act != displayLyricCenterIndex {
            let oldCenter = displayLyricCenterIndex
            displayLyricCenterIndex = act
            if barMode == .lyrics && !nowPlayingContainer.isHidden {
                renderLyricSlots(animatedDirection: act > oldCenter ? 1 : -1)
            } else {
                renderLyricSlots(animatedDirection: 0)
            }
        } else {
            renderLyricSlots(animatedDirection: 0)
        }
    }

    private func computeActiveLyricIndex(for elapsed: TimeInterval) -> Int? {
        guard let lyrics = currentLyrics, lyrics.isSynced, !lyrics.lines.isEmpty else { return nil }
        let target = elapsed + 0.15
        var matched: Int?
        for (idx, line) in lyrics.lines.enumerated() {
            if let t = line.time, t <= target {
                matched = idx
            } else if let t = line.time, t > target {
                break
            }
        }
        return matched
    }

    private func karaokeProgress(for lineIndex: Int, elapsed: TimeInterval) -> Double {
        guard let lyrics = currentLyrics, lyrics.isSynced,
              lyrics.lines.indices.contains(lineIndex),
              let start = lyrics.lines[lineIndex].time else {
            return 1.0
        }
        let singingWindow: TimeInterval
        if lyrics.lines.indices.contains(lineIndex + 1), let nextT = lyrics.lines[lineIndex + 1].time {
            let gap = max(0.8, nextT - start)
            singingWindow = gap > 8.5 ? 6.5 : max(0.8, gap * 0.90)
        } else {
            let remaining = max(1.5, lastDuration - start)
            singingWindow = min(remaining * 0.85, 6.0)
        }
        return min(max((elapsed - start) / max(0.6, singingWindow), 0.0), 1.0)
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

    private func buildKaraokeAttributedText(
        text: String,
        font: UIFont,
        litColor: UIColor,
        dimmedColor: UIColor,
        progress: Double
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2.5

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
        let cursor = Double(ranges.count) * clampedProg

        for (i, range) in ranges.enumerated() {
            let rawT = (cursor - Double(i)) / 2.4 + 0.5
            let t = CGFloat(min(max(rawT, 0.0), 1.0))
            let color = interpolateColor(from: dimmedColor, to: litColor, t: t)
            attr.addAttribute(.foregroundColor, value: color, range: range)

            if clampedProg > 0.01 && clampedProg < 0.99 {
                let dist = abs(cursor - Double(i))
                if dist < 3.6 {
                    let lift = CGFloat((1.0 - dist / 3.6) * 1.55)
                    attr.addAttribute(.baselineOffset, value: lift, range: range)
                }
            }
        }
        return attr
    }

    private func updateActiveLyricReadingEffect(elapsed: TimeInterval) {
        guard let lyrics = currentLyrics, lyrics.isSynced,
              let actIdx = activeLyricIndex,
              lyrics.lines.indices.contains(actIdx) else { return }

        let centerIdx = min(max(0, displayLyricCenterIndex), lyrics.lines.count - 1)
        let targetLabel: UILabel?
        let font: UIFont
        if actIdx == centerIdx {
            targetLabel = lyricCurrentLabel
            font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        } else if actIdx == centerIdx - 1 {
            targetLabel = lyricPrevLabel
            font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        } else if actIdx == centerIdx + 1 {
            targetLabel = lyricNextLabel
            font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        } else {
            targetLabel = nil
            font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        }

        guard let label = targetLabel else { return }
        let litColor = theme == .darkPod ? UIColor.white : theme.highlightBottom
        let dimmedColor = (theme == .darkPod ? UIColor.white : theme.primaryText).withAlphaComponent(0.36)
        let prog = karaokeProgress(for: actIdx, elapsed: elapsed)
        label.attributedText = buildKaraokeAttributedText(
            text: lyrics.lines[actIdx].text,
            font: font,
            litColor: litColor,
            dimmedColor: dimmedColor,
            progress: prog
        )
    }

    private func animateActiveLyricBounce(on label: UILabel) {
        label.transform = CGAffineTransform(translationX: 0, y: 2.5).scaledBy(x: 0.94, y: 0.94)
        UIView.animate(
            withDuration: 0.44,
            delay: 0,
            usingSpringWithDamping: 0.55,
            initialSpringVelocity: 0.7,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                label.transform = .identity
            }
        )
    }

    private func renderLyricSlots(animatedDirection: Int) {
        guard let lyrics = currentLyrics, !lyrics.lines.isEmpty else {
            activeLyricSnapshot?.removeFromSuperview()
            activeLyricSnapshot = nil
            lyricsSlotsContainer.layer.removeAllAnimations()
            lyricsSlotsContainer.transform = .identity
            lyricsSlotsContainer.alpha = 1.0

            lyricPrevLabel.attributedText = nil
            lyricPrevLabel.text = ""
            lyricNextLabel.attributedText = nil
            lyricNextLabel.text = ""
            lyricCurrentLabel.attributedText = nil
            lyricCurrentLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
            lyricCurrentLabel.textColor = theme.secondaryText.withAlphaComponent(0.75)
            lyricCurrentLabel.layer.shadowOpacity = 0.0
            if lyricsLoadingTrackId != nil {
                lyricCurrentLabel.text = "Mencari lirik..."
            } else {
                lyricCurrentLabel.text = "Lirik tidak tersedia"
            }
            return
        }

        let lines = lyrics.lines
        let centerIdx = min(max(0, displayLyricCenterIndex), lines.count - 1)
        let prevIdx = centerIdx - 1
        let nextIdx = centerIdx + 1

        var snapshot: UIView?
        if animatedDirection != 0 && barMode == .lyrics && !nowPlayingContainer.isHidden && lyricsContainerView.bounds.height > 10 {
            activeLyricSnapshot?.removeFromSuperview()
            lyricsSlotsContainer.layer.removeAllAnimations()
            lyricsSlotsContainer.transform = .identity
            lyricsSlotsContainer.alpha = 1.0
            if let snap = lyricsSlotsContainer.snapshotView(afterScreenUpdates: false) {
                snap.frame = lyricsSlotsContainer.frame
                lyricsContainerView.addSubview(snap)
                activeLyricSnapshot = snap
                snapshot = snap
            }
        }

        let smoothElapsed = currentSmoothLyricsElapsed()
        var bouncedLabel: UILabel?

        func applySlotStyle(_ label: UILabel, index: Int?, isCenterSlot: Bool) {
            guard let idx = index, lines.indices.contains(idx) else {
                label.attributedText = nil
                label.text = ""
                label.layer.shadowOpacity = 0.0
                return
            }

            let isSongActiveLine: Bool
            if lyrics.isSynced {
                isSongActiveLine = (activeLyricIndex == idx)
            } else {
                isSongActiveLine = isCenterSlot
            }

            let glowColor = (theme == .darkPod ? UIColor.white : theme.highlightTop).cgColor
            let activeTextColor = theme == .darkPod ? UIColor.white : theme.highlightBottom
            let activeDimmedColor = (theme == .darkPod ? UIColor.white : theme.primaryText).withAlphaComponent(0.36)

            if isCenterSlot {
                if isSongActiveLine {
                    let font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
                    label.font = font
                    if lyrics.isSynced {
                        let prog = karaokeProgress(for: idx, elapsed: smoothElapsed)
                        label.attributedText = buildKaraokeAttributedText(
                            text: lines[idx].text,
                            font: font,
                            litColor: activeTextColor,
                            dimmedColor: activeDimmedColor,
                            progress: prog
                        )
                    } else {
                        label.attributedText = nil
                        label.text = lines[idx].text
                        label.textColor = activeTextColor
                    }
                    label.layer.shadowColor = glowColor
                    label.layer.shadowRadius = 6.0
                    label.layer.shadowOpacity = theme == .darkPod ? 0.80 : 0.48
                    label.layer.shadowOffset = .zero
                    bouncedLabel = label
                } else {
                    label.attributedText = nil
                    label.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
                    label.text = lines[idx].text
                    label.textColor = theme.primaryText.withAlphaComponent(0.72)
                    label.layer.shadowOpacity = 0.0
                }
            } else {
                if isSongActiveLine {
                    let font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
                    label.font = font
                    if lyrics.isSynced {
                        let prog = karaokeProgress(for: idx, elapsed: smoothElapsed)
                        label.attributedText = buildKaraokeAttributedText(
                            text: lines[idx].text,
                            font: font,
                            litColor: activeTextColor,
                            dimmedColor: activeDimmedColor,
                            progress: prog
                        )
                    } else {
                        label.attributedText = nil
                        label.text = lines[idx].text
                        label.textColor = activeTextColor
                    }
                    label.layer.shadowColor = glowColor
                    label.layer.shadowRadius = 5.0
                    label.layer.shadowOpacity = theme == .darkPod ? 0.72 : 0.42
                    label.layer.shadowOffset = .zero
                    bouncedLabel = label
                } else {
                    label.attributedText = nil
                    label.font = UIFont.systemFont(ofSize: 10.5, weight: .medium)
                    label.text = lines[idx].text
                    label.textColor = theme.secondaryText.withAlphaComponent(0.42)
                    label.layer.shadowOpacity = 0.0
                }
            }
        }

        applySlotStyle(lyricPrevLabel, index: prevIdx >= 0 ? prevIdx : nil, isCenterSlot: false)
        applySlotStyle(lyricCurrentLabel, index: centerIdx, isCenterSlot: true)
        applySlotStyle(lyricNextLabel, index: nextIdx < lines.count ? nextIdx : nil, isCenterSlot: false)
        lyricsContainerView.layoutIfNeeded()

        if let bounceTarget = bouncedLabel,
           let actIdx = activeLyricIndex,
           actIdx != lastBouncedLineIndex,
           barMode == .lyrics,
           !nowPlayingContainer.isHidden {
            lastBouncedLineIndex = actIdx
            animateActiveLyricBounce(on: bounceTarget)
        }

        if let snap = snapshot {
            let offset: CGFloat = animatedDirection > 0 ? 30.0 : -30.0
            lyricsSlotsContainer.transform = CGAffineTransform(translationX: 0, y: offset)
            lyricsSlotsContainer.alpha = 0.15

            UIView.animate(
                withDuration: 0.24,
                delay: 0,
                options: [.curveEaseOut],
                animations: {
                    self.lyricsSlotsContainer.transform = .identity
                    self.lyricsSlotsContainer.alpha = 1.0
                    snap.transform = CGAffineTransform(translationX: 0, y: -offset)
                    snap.alpha = 0.0
                },
                completion: { _ in
                    snap.removeFromSuperview()
                }
            )
        }
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

        let displayElapsed = isActive ? max(0, elapsedSeconds) : 0
        sleepCountdownLabel.text = formatTime(TimeInterval(displayElapsed))
        sleepTargetLabel.text = setMinutes > 0 ? formatTime(TimeInterval(setMinutes * 60)) : "OFF"
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
            updateActiveLyricReadingEffect(elapsed: elapsed)
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