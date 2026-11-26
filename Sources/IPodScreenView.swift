import UIKit

enum IPodColorTheme {
    case classicBlue
    case sepiaPod

    var screenBackground: UIColor {
        switch self {
        case .classicBlue: return UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.96, green: 0.92, blue: 0.83, alpha: 1.0)
        }
    }

    var primaryText: UIColor {
        switch self {
        case .classicBlue: return UIColor(white: 0.10, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.24, green: 0.17, blue: 0.10, alpha: 1.0)
        }
    }

    var secondaryText: UIColor {
        switch self {
        case .classicBlue: return UIColor(white: 0.42, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.48, green: 0.37, blue: 0.25, alpha: 1.0)
        }
    }

    var highlightTop: UIColor {
        switch self {
        case .classicBlue: return UIColor(red: 0.24, green: 0.56, blue: 0.94, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 1.0)
        }
    }

    var highlightBottom: UIColor {
        switch self {
        case .classicBlue: return UIColor(red: 0.11, green: 0.38, blue: 0.80, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.44, green: 0.28, blue: 0.13, alpha: 1.0)
        }
    }
}

struct IPodMenuRow {
    let title: String
    let hasSubmenu: Bool
}

class IPodMenuCell: UITableViewCell {
    let titleLabel = UILabel()
    let arrowLabel = UILabel()
    private let highlightGradient = CAGradientLayer()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        highlightGradient.isHidden = true
        contentView.layer.insertSublayer(highlightGradient, at: 0)

        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        arrowLabel.text = "›"
        arrowLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        arrowLabel.textAlignment = .right
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: arrowLabel.leadingAnchor, constant: -6),

            arrowLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            arrowLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowLabel.widthAnchor.constraint(equalToConstant: 16)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlightGradient.frame = contentView.bounds
    }

    func configure(row: IPodMenuRow, isSelected: Bool, theme: IPodColorTheme) {
        titleLabel.text = row.title
        arrowLabel.isHidden = !row.hasSubmenu
        highlightGradient.colors = [theme.highlightTop.cgColor, theme.highlightBottom.cgColor]

        if isSelected {
            highlightGradient.isHidden = false
            titleLabel.textColor = .white
            arrowLabel.textColor = .white
        } else {
            highlightGradient.isHidden = true
            titleLabel.textColor = theme.primaryText
            arrowLabel.textColor = theme.secondaryText
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
        coverImageView.layer.borderWidth = 1.0
        coverImageView.layer.borderColor = UIColor(white: 0.72, alpha: 1.0).cgColor
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
            coverImageView.widthAnchor.constraint(equalToConstant: 88),
            coverImageView.heightAnchor.constraint(equalToConstant: 88),

            reflectionImageView.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 1),
            reflectionImageView.centerXAnchor.constraint(equalTo: coverImageView.centerXAnchor),
            reflectionImageView.widthAnchor.constraint(equalToConstant: 88),
            reflectionImageView.heightAnchor.constraint(equalToConstant: 74)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reflectionMask.frame = reflectionImageView.bounds
    }

    func configure(image: UIImage?) {
        coverImageView.image = image
        reflectionImageView.image = image
    }

    required init?(coder: NSCoder) { fatalError() }
}

class IPodScreenView: UIView, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var theme: IPodColorTheme = .sepiaPod {
        didSet { applyTheme() }
    }

    var onCoverFlowTrackSelected: ((Int) -> Void)?
    var onSeekRatioChanged: ((Double) -> Void)?

    // Top Status Bar
    private let headerBar = UIView()
    private let headerBorder = UIView()
    private let playStateIcon = UILabel()
    private let headerTitleLabel = UILabel()
    private let batteryView = UIView()
    private let batteryFill = UIView()

    // Menu List View
    private let tableView = UITableView()
    private var rows: [IPodMenuRow] = []
    private(set) var selectedIndex: Int = 0

    // Horizontal Cover Flow View (3 Kiri, 1 Tengah, 3 Kanan rapat tanpa celah)
    private let coverFlowContainer = UIView()
    private var coverCollectionView: UICollectionView!
    private let coverTitleLabel = UILabel()
    private let coverArtistLabel = UILabel()
    private var coverTracks: [IPodTrack] = []
    private(set) var isCoverFlowActive = false
    private let coverItemWidth: CGFloat = 92
    private let coverItemSpacing: CGFloat = -54 // Jarak rapat (stride 38pt) sehingga 7 sampul tersusun padat tanpa gang kosong

    // Now Playing View
    private let nowPlayingContainer = UIView()
    private let trackIndexLabel = UILabel()
    private let artworkView = UIImageView()
    private let trackTitleLabel = UILabel()
    private let trackArtistLabel = UILabel()
    private let trackAlbumLabel = UILabel()
    private let progressTouchArea = UIView()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let progressKnob = UIView()
    private let elapsedLabel = UILabel()
    private let remainingLabel = UILabel()
    private var progressWidthConstraint: NSLayoutConstraint!
    private var isScrubbing = false
    private var lastDisplayedTrackId: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 8
        layer.borderWidth = 3.0
        layer.borderColor = UIColor(white: 0.12, alpha: 1.0).cgColor
        clipsToBounds = true
        setupUI()
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerBar)

        headerBorder.backgroundColor = UIColor(white: 0.72, alpha: 1.0)
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(headerBorder)

        playStateIcon.text = "❚❚"
        playStateIcon.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        playStateIcon.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(playStateIcon)

        headerTitleLabel.text = "iPod"
        headerTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        headerTitleLabel.textAlignment = .center
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(headerTitleLabel)

        batteryView.layer.borderWidth = 1.2
        batteryView.layer.borderColor = UIColor(white: 0.35, alpha: 1.0).cgColor
        batteryView.layer.cornerRadius = 2
        batteryView.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(batteryView)

        batteryFill.backgroundColor = UIColor(red: 0.25, green: 0.75, blue: 0.32, alpha: 1.0)
        batteryFill.translatesAutoresizingMaskIntoConstraints = false
        batteryView.addSubview(batteryFill)

        // Menu Table
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(IPodMenuCell.self, forCellReuseIdentifier: "IPodCell")
        tableView.rowHeight = 32
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
        flowLayout.itemSize = CGSize(width: coverItemWidth, height: 174)

        coverCollectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        coverCollectionView.dataSource = self
        coverCollectionView.delegate = self
        coverCollectionView.register(IPodCoverFlowCell.self, forCellWithReuseIdentifier: "CoverCell")
        coverCollectionView.backgroundColor = .clear
        coverCollectionView.showsHorizontalScrollIndicator = false
        coverCollectionView.decelerationRate = .fast
        coverCollectionView.translatesAutoresizingMaskIntoConstraints = false
        coverFlowContainer.addSubview(coverCollectionView)

        coverTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        coverTitleLabel.textAlignment = .center
        coverTitleLabel.lineBreakMode = .byTruncatingTail
        coverTitleLabel.isUserInteractionEnabled = false
        coverTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        coverFlowContainer.addSubview(coverTitleLabel)

        coverArtistLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        coverArtistLabel.textAlignment = .center
        coverArtistLabel.lineBreakMode = .byTruncatingTail
        coverArtistLabel.isUserInteractionEnabled = false
        coverArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        coverFlowContainer.addSubview(coverArtistLabel)

        // Now Playing Container
        nowPlayingContainer.isHidden = true
        nowPlayingContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nowPlayingContainer)

        trackIndexLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        trackIndexLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(trackIndexLabel)

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.borderWidth = 1.0
        artworkView.layer.borderColor = UIColor(white: 0.65, alpha: 1.0).cgColor
        artworkView.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(artworkView)

        trackTitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        trackTitleLabel.numberOfLines = 2
        trackTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(trackTitleLabel)

        trackArtistLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        trackArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(trackArtistLabel)

        trackAlbumLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        trackAlbumLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(trackAlbumLabel)

        progressTouchArea.backgroundColor = .clear
        progressTouchArea.isUserInteractionEnabled = true
        progressTouchArea.translatesAutoresizingMaskIntoConstraints = false
        let panSeek = UIPanGestureRecognizer(target: self, action: #selector(handleProgressScrub(_:)))
        let tapSeek = UITapGestureRecognizer(target: self, action: #selector(handleProgressTap(_:)))
        progressTouchArea.addGestureRecognizer(panSeek)
        progressTouchArea.addGestureRecognizer(tapSeek)
        nowPlayingContainer.addSubview(progressTouchArea)

        progressTrack.backgroundColor = UIColor(white: 0.80, alpha: 1.0)
        progressTrack.layer.cornerRadius = 4.5
        progressTrack.layer.borderWidth = 0.8
        progressTrack.layer.borderColor = UIColor(white: 0.58, alpha: 1.0).cgColor
        progressTrack.clipsToBounds = true
        progressTrack.isUserInteractionEnabled = false
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTouchArea.addSubview(progressTrack)

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)
        progressWidthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)

        progressKnob.backgroundColor = .white
        progressKnob.layer.cornerRadius = 6
        progressKnob.layer.borderWidth = 1.2
        progressKnob.layer.borderColor = UIColor(white: 0.35, alpha: 1.0).cgColor
        progressKnob.isUserInteractionEnabled = false
        progressKnob.translatesAutoresizingMaskIntoConstraints = false
        progressTouchArea.addSubview(progressKnob)

        elapsedLabel.text = "0:00"
        elapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        elapsedLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(elapsedLabel)

        remainingLabel.text = "-0:00"
        remainingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        remainingLabel.textAlignment = .right
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(remainingLabel)

        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let batRatio: CGFloat = level >= 0 ? CGFloat(max(0.15, level)) : 0.85

        NSLayoutConstraint.activate([
            headerBar.topAnchor.constraint(equalTo: topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 26),

            headerBorder.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor),
            headerBorder.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            headerBorder.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
            headerBorder.heightAnchor.constraint(equalToConstant: 1),

            playStateIcon.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 8),
            playStateIcon.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            playStateIcon.widthAnchor.constraint(equalToConstant: 20),

            batteryView.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -8),
            batteryView.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            batteryView.widthAnchor.constraint(equalToConstant: 22),
            batteryView.heightAnchor.constraint(equalToConstant: 11),

            batteryFill.topAnchor.constraint(equalTo: batteryView.topAnchor, constant: 1.5),
            batteryFill.bottomAnchor.constraint(equalTo: batteryView.bottomAnchor, constant: -1.5),
            batteryFill.leadingAnchor.constraint(equalTo: batteryView.leadingAnchor, constant: 1.5),
            batteryFill.widthAnchor.constraint(equalTo: batteryView.widthAnchor, multiplier: batRatio, constant: -3),

            headerTitleLabel.leadingAnchor.constraint(equalTo: playStateIcon.trailingAnchor, constant: 4),
            headerTitleLabel.trailingAnchor.constraint(equalTo: batteryView.leadingAnchor, constant: -4),
            headerTitleLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
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

            coverArtistLabel.bottomAnchor.constraint(equalTo: coverFlowContainer.bottomAnchor, constant: -10),
            coverArtistLabel.leadingAnchor.constraint(equalTo: coverFlowContainer.leadingAnchor, constant: 14),
            coverArtistLabel.trailingAnchor.constraint(equalTo: coverFlowContainer.trailingAnchor, constant: -14),

            coverTitleLabel.bottomAnchor.constraint(equalTo: coverArtistLabel.topAnchor, constant: -2),
            coverTitleLabel.leadingAnchor.constraint(equalTo: coverArtistLabel.leadingAnchor),
            coverTitleLabel.trailingAnchor.constraint(equalTo: coverArtistLabel.trailingAnchor),

            nowPlayingContainer.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            nowPlayingContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            nowPlayingContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            nowPlayingContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            trackIndexLabel.topAnchor.constraint(equalTo: nowPlayingContainer.topAnchor, constant: 8),
            trackIndexLabel.leadingAnchor.constraint(equalTo: nowPlayingContainer.leadingAnchor, constant: 12),

            artworkView.topAnchor.constraint(equalTo: trackIndexLabel.bottomAnchor, constant: 8),
            artworkView.leadingAnchor.constraint(equalTo: nowPlayingContainer.leadingAnchor, constant: 12),
            artworkView.widthAnchor.constraint(equalToConstant: 96),
            artworkView.heightAnchor.constraint(equalToConstant: 96),

            trackTitleLabel.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: 4),
            trackTitleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 10),
            trackTitleLabel.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -10),

            trackArtistLabel.topAnchor.constraint(equalTo: trackTitleLabel.bottomAnchor, constant: 6),
            trackArtistLabel.leadingAnchor.constraint(equalTo: trackTitleLabel.leadingAnchor),
            trackArtistLabel.trailingAnchor.constraint(equalTo: trackTitleLabel.trailingAnchor),

            trackAlbumLabel.topAnchor.constraint(equalTo: trackArtistLabel.bottomAnchor, constant: 4),
            trackAlbumLabel.leadingAnchor.constraint(equalTo: trackTitleLabel.leadingAnchor),
            trackAlbumLabel.trailingAnchor.constraint(equalTo: trackTitleLabel.trailingAnchor),

            progressTouchArea.leadingAnchor.constraint(equalTo: nowPlayingContainer.leadingAnchor, constant: 12),
            progressTouchArea.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -12),
            progressTouchArea.bottomAnchor.constraint(equalTo: elapsedLabel.topAnchor, constant: -2),
            progressTouchArea.heightAnchor.constraint(equalToConstant: 24),

            progressTrack.leadingAnchor.constraint(equalTo: progressTouchArea.leadingAnchor),
            progressTrack.trailingAnchor.constraint(equalTo: progressTouchArea.trailingAnchor),
            progressTrack.centerYAnchor.constraint(equalTo: progressTouchArea.centerYAnchor),
            progressTrack.heightAnchor.constraint(equalToConstant: 9),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressWidthConstraint,

            progressKnob.centerYAnchor.constraint(equalTo: progressTrack.centerYAnchor),
            progressKnob.centerXAnchor.constraint(equalTo: progressFill.trailingAnchor),
            progressKnob.widthAnchor.constraint(equalToConstant: 12),
            progressKnob.heightAnchor.constraint(equalToConstant: 12),

            elapsedLabel.leadingAnchor.constraint(equalTo: progressTouchArea.leadingAnchor),
            elapsedLabel.bottomAnchor.constraint(equalTo: nowPlayingContainer.bottomAnchor, constant: -8),

            remainingLabel.trailingAnchor.constraint(equalTo: progressTouchArea.trailingAnchor),
            remainingLabel.bottomAnchor.constraint(equalTo: nowPlayingContainer.bottomAnchor, constant: -8)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let layout = coverCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let sideInset = max(0, (bounds.width - layout.itemSize.width) / 2.0)
            layout.sectionInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
        }
        applyCoverFlowTransforms()
    }

    private func applyTheme() {
        backgroundColor = theme.screenBackground
        headerBar.backgroundColor = theme == .sepiaPod
            ? UIColor(red: 0.90, green: 0.84, blue: 0.72, alpha: 1.0)
            : UIColor(white: 0.90, alpha: 1.0)
        headerTitleLabel.textColor = theme.primaryText
        playStateIcon.textColor = theme.highlightBottom
        coverTitleLabel.textColor = theme.primaryText
        coverArtistLabel.textColor = theme.secondaryText
        trackIndexLabel.textColor = theme.secondaryText
        trackTitleLabel.textColor = theme.primaryText
        trackArtistLabel.textColor = theme.secondaryText
        trackAlbumLabel.textColor = theme.secondaryText
        elapsedLabel.textColor = theme.primaryText
        remainingLabel.textColor = theme.primaryText
        progressFill.backgroundColor = theme.highlightTop
        tableView.reloadData()
        coverCollectionView.reloadData()
    }

    // MARK: - Touchscreen Scrubbing
    @objc private func handleProgressTap(_ gesture: UITapGestureRecognizer) {
        let pt = gesture.location(in: progressTrack)
        let width = max(progressTrack.bounds.width, 1.0)
        let ratio = Double(min(max(pt.x / width, 0.0), 1.0))
        progressWidthConstraint.constant = CGFloat(ratio) * width
        onSeekRatioChanged?(ratio)
    }

    @objc private func handleProgressScrub(_ gesture: UIPanGestureRecognizer) {
        let pt = gesture.location(in: progressTrack)
        let width = max(progressTrack.bounds.width, 1.0)
        let ratio = Double(min(max(pt.x / width, 0.0), 1.0))

        switch gesture.state {
        case .began, .changed:
            isScrubbing = true
            progressWidthConstraint.constant = CGFloat(ratio) * width
            onSeekRatioChanged?(ratio)
        case .ended, .cancelled:
            isScrubbing = false
            onSeekRatioChanged?(ratio)
        default:
            break
        }
    }

    func updatePlayState(isPlaying: Bool) {
        playStateIcon.text = isPlaying ? "▶" : "❚❚"
    }

    func showMenu(title: String, items: [IPodMenuRow], selectedIndex: Int = 0) {
        headerTitleLabel.text = title
        self.rows = items
        self.selectedIndex = min(max(0, selectedIndex), max(0, items.count - 1))
        self.isCoverFlowActive = false
        nowPlayingContainer.isHidden = true
        coverFlowContainer.isHidden = true
        tableView.isHidden = false
        tableView.reloadData()
        if !rows.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: self.selectedIndex, section: 0), at: .none, animated: false)
        }
    }

    func showSongsCoverFlow(title: String, tracks: [IPodTrack], selectedIndex: Int = 0, animateFromNowPlaying: Bool = false) {
        let wasNowPlaying = !nowPlayingContainer.isHidden
        let sourceArtworkFrame = artworkView.convert(artworkView.bounds, to: self)
        let sourceArtworkImage = artworkView.image

        headerTitleLabel.text = title
        self.coverTracks = tracks
        self.selectedIndex = min(max(0, selectedIndex), max(0, tracks.count - 1))
        self.isCoverFlowActive = true

        nowPlayingContainer.isHidden = true
        tableView.isHidden = true
        coverFlowContainer.isHidden = false

        // Paksa layout selesai terlebih dahulu agar semua sel langsung ter-transform 3D dan tidak tampil menghadap depan semua
        setNeedsLayout()
        layoutIfNeeded()
        coverCollectionView.reloadData()
        coverCollectionView.layoutIfNeeded()

        if !tracks.isEmpty {
            scrollCoverFlowToIndex(self.selectedIndex, animated: false, bounceDirection: 0)
            updateCoverFlowCaption(for: self.selectedIndex)
            coverCollectionView.layoutIfNeeded()
            applyCoverFlowTransforms()
        } else {
            coverTitleLabel.text = "Tidak ada lagu"
            coverArtistLabel.text = "Sinkronkan lagu ke Music/Documents"
        }

        // Animasi seamless sampul Now Playing melayang dan menyatu ke tengah atas barisan Cover Flow
        if animateFromNowPlaying && wasNowPlaying && !tracks.isEmpty {
            let targetCenterX = bounds.width / 2.0
            let targetTopY: CGFloat = 26.0 + 4.0 + 6.0 // headerBar (26) + collectionTop (4) + cellCoverTop (6)
            let targetFrame = CGRect(x: targetCenterX - 44.0, y: targetTopY, width: 88.0, height: 88.0)

            let flyingCover = UIImageView(frame: sourceArtworkFrame)
            flyingCover.image = sourceArtworkImage ?? makeDefaultNoteArtwork()
            flyingCover.contentMode = .scaleAspectFill
            flyingCover.clipsToBounds = true
            flyingCover.layer.borderWidth = 1.0
            flyingCover.layer.borderColor = UIColor(white: 0.72, alpha: 1.0).cgColor
            addSubview(flyingCover)

            // Sembunyikan sementara sel tengah agar tidak bertumpuk selama sampul melayang
            let centerIndexPath = IndexPath(item: self.selectedIndex, section: 0)
            let centerCell = coverCollectionView.cellForItem(at: centerIndexPath)
            centerCell?.alpha = 0.0

            coverFlowContainer.alpha = 0.0
            coverFlowContainer.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)

            UIView.animate(
                withDuration: 0.36,
                delay: 0,
                usingSpringWithDamping: 0.84,
                initialSpringVelocity: 0.3,
                options: [.curveEaseOut],
                animations: {
                    flyingCover.frame = targetFrame
                    self.coverFlowContainer.alpha = 1.0
                    self.coverFlowContainer.transform = .identity
                },
                completion: { _ in
                    centerCell?.alpha = 1.0
                    flyingCover.removeFromSuperview()
                    self.applyCoverFlowTransforms()
                }
            )
        }
    }

    private func scrollCoverFlowToIndex(_ index: Int, animated: Bool, bounceDirection: Int) {
        let stepStride = coverItemWidth + coverItemSpacing // 92 + (-54) = 38pt per slot
        let targetX = CGFloat(index) * stepStride

        if animated && bounceDirection != 0 {
            let overshoot = CGFloat(bounceDirection) * 7.0
            UIView.animate(withDuration: 0.14, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
                self.coverCollectionView.contentOffset = CGPoint(x: targetX + overshoot, y: 0)
                self.applyCoverFlowTransforms()
            }, completion: { _ in
                UIView.animate(
                    withDuration: 0.24,
                    delay: 0,
                    usingSpringWithDamping: 0.62,
                    initialSpringVelocity: 0.8,
                    options: [.curveEaseOut, .allowUserInteraction],
                    animations: {
                        self.coverCollectionView.contentOffset = CGPoint(x: targetX, y: 0)
                        self.applyCoverFlowTransforms()
                    }
                )
            })
        } else {
            coverCollectionView.contentOffset = CGPoint(x: targetX, y: 0)
            applyCoverFlowTransforms()
        }
    }

    func moveSelection(by delta: Int) {
        guard nowPlayingContainer.isHidden else { return }

        if isCoverFlowActive {
            guard !coverTracks.isEmpty else { return }
            let next = min(max(0, selectedIndex + delta), coverTracks.count - 1)
            if next != selectedIndex {
                let direction = next > selectedIndex ? 1 : -1
                selectedIndex = next
                // Putar 1 langkah pelan mendapat efek bouncing pegas; putar cepat (>1 langkah) langsung meluncur mulus
                scrollCoverFlowToIndex(selectedIndex, animated: abs(delta) == 1, bounceDirection: direction)
                updateCoverFlowCaption(for: selectedIndex)
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
        guard coverTracks.indices.contains(index) else { return }
        let track = coverTracks[index]
        coverTitleLabel.text = track.title
        coverArtistLabel.text = track.artist
    }

    private func applyCoverFlowTransforms() {
        guard isCoverFlowActive else { return }
        let centerX = coverCollectionView.contentOffset.x + coverCollectionView.bounds.width / 2.0
        let stepStride = coverItemWidth + coverItemSpacing // 38pt per slot

        for cell in coverCollectionView.visibleCells {
            let distance = cell.center.x - centerX
            let slotOffset = max(-3.6, min(3.6, distance / stepStride))
            let absSlot = abs(slotOffset)
            let sign: CGFloat = slotOffset >= 0 ? 1.0 : -1.0

            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 360.0

            // Sampul tengah menghadap lurus (0 rad); sampul ke-1, ke-2, dan ke-3 miring konsisten
            let angle: CGFloat
            if absSlot < 0.20 {
                angle = -slotOffset * 2.2
            } else {
                angle = -sign * min(.pi / 2.35, 0.84 + (absSlot - 0.20) * 0.10)
            }

            // Skala mengecil bertahap namun tetap proporsional sampai sampul ke-3
            let scale = max(0.76, 1.0 - (absSlot * 0.065))

            // Tarik masuk bertahap untuk slot 1, 2, dan 3 agar tidak ada gang kosong di antara sampul pinggir
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

    func showNowPlaying(track: IPodTrack, index: Int, total: Int, transitionDirection: Int = 0) {
        headerTitleLabel.text = "Now Playing"
        tableView.isHidden = true
        coverFlowContainer.isHidden = true
        isCoverFlowActive = false
        nowPlayingContainer.isHidden = false

        trackIndexLabel.text = "\(index + 1) of \(total)"
        trackTitleLabel.text = track.title
        trackArtistLabel.text = track.artist
        trackAlbumLabel.text = track.album

        let nextImage = track.artworkImage ?? makeDefaultNoteArtwork()

        if transitionDirection != 0 && lastDisplayedTrackId != track.id {
            let dir: CGFloat = transitionDirection > 0 ? 1.0 : -1.0
            var startTransform = CATransform3DIdentity
            startTransform.m34 = -1.0 / 350.0
            startTransform = CATransform3DTranslate(startTransform, dir * 34.0, 0, -25.0)
            startTransform = CATransform3DRotate(startTransform, -dir * (.pi / 3.0), 0, 1, 0)
            startTransform = CATransform3DScale(startTransform, 0.84, 0.84, 1.0)

            artworkView.image = nextImage
            artworkView.layer.transform = startTransform
            artworkView.alpha = 0.55

            UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: [.curveEaseOut], animations: {
                self.artworkView.layer.transform = CATransform3DIdentity
                self.artworkView.alpha = 1.0
            })
        } else {
            artworkView.layer.transform = CATransform3DIdentity
            artworkView.alpha = 1.0
            artworkView.image = nextImage
        }

        lastDisplayedTrackId = track.id
    }

    func updateProgress(elapsed: TimeInterval, duration: TimeInterval) {
        let safeDur = max(duration, 1.0)
        if !isScrubbing {
            let ratio = CGFloat(min(max(elapsed / safeDur, 0.0), 1.0))
            progressWidthConstraint.constant = progressTrack.bounds.width * ratio
        }
        elapsedLabel.text = formatTime(elapsed)
        remainingLabel.text = "-\(formatTime(max(0, safeDur - elapsed)))"
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func makeDefaultNoteArtwork() -> UIImage? {
        let size = CGSize(width: 140, height: 140)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        theme.highlightTop.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 52, weight: .bold),
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
        cell.configure(row: rows[indexPath.row], isSelected: indexPath.row == selectedIndex, theme: theme)
        return cell
    }

    // MARK: - UICollectionViewDataSource & Delegate (Cover Flow)
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return coverTracks.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CoverCell", for: indexPath) as! IPodCoverFlowCell
        let track = coverTracks[indexPath.item]
        cell.configure(image: track.artworkImage ?? makeDefaultNoteArtwork())
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        applyCoverFlowTransforms()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == selectedIndex {
            onCoverFlowTrackSelected?(indexPath.item)
        } else {
            let direction = indexPath.item > selectedIndex ? 1 : -1
            selectedIndex = indexPath.item
            scrollCoverFlowToIndex(selectedIndex, animated: true, bounceDirection: direction)
            updateCoverFlowCaption(for: selectedIndex)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === coverCollectionView else { return }
        applyCoverFlowTransforms()

        let stepStride = coverItemWidth + coverItemSpacing
        let rawIndex = Int(round(coverCollectionView.contentOffset.x / stepStride))
        let clamped = min(max(0, rawIndex), max(0, coverTracks.count - 1))
        if clamped != selectedIndex {
            selectedIndex = clamped
            updateCoverFlowCaption(for: selectedIndex)
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView === coverCollectionView else { return }
        let stepStride = coverItemWidth + coverItemSpacing
        let rawIndex = Int(round(targetContentOffset.pointee.x / stepStride))
        let clamped = min(max(0, rawIndex), max(0, coverTracks.count - 1))
        targetContentOffset.pointee.x = CGFloat(clamped) * stepStride
    }
}