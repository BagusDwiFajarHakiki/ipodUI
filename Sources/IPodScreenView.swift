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

// MARK: - Cover Flow Cell (Sampul Berjejer Kanan-Kiri + Refleksi Bawah)
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
        reflectionImageView.alpha = 0.28
        reflectionImageView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
        reflectionImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(reflectionImageView)

        reflectionMask.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor
        ]
        reflectionMask.locations = [0.45, 1.0]
        reflectionImageView.layer.mask = reflectionMask

        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            coverImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: 96),
            coverImageView.heightAnchor.constraint(equalToConstant: 96),

            reflectionImageView.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 2),
            reflectionImageView.centerXAnchor.constraint(equalTo: coverImageView.centerXAnchor),
            reflectionImageView.widthAnchor.constraint(equalToConstant: 96),
            reflectionImageView.heightAnchor.constraint(equalToConstant: 26)
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

    // Horizontal Cover Flow View (Menu Songs)
    private let coverFlowContainer = UIView()
    private var coverCollectionView: UICollectionView!
    private let coverTitleLabel = UILabel()
    private let coverArtistLabel = UILabel()
    private var coverTracks: [IPodTrack] = []
    private(set) var isCoverFlowActive = false

    // Now Playing View
    private let nowPlayingContainer = UIView()
    private let trackIndexLabel = UILabel()
    private let artworkView = UIImageView()
    private let trackTitleLabel = UILabel()
    private let trackArtistLabel = UILabel()
    private let trackAlbumLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let elapsedLabel = UILabel()
    private let remainingLabel = UILabel()
    private var progressWidthConstraint: NSLayoutConstraint!

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
        // Header Bar
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

        // Cover Flow Container (Sampul berjejer kanan-kiri + judul di bawah)
        coverFlowContainer.isHidden = true
        coverFlowContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(coverFlowContainer)

        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumLineSpacing = 8
        flowLayout.itemSize = CGSize(width: 102, height: 128)

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
        coverTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        coverFlowContainer.addSubview(coverTitleLabel)

        coverArtistLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        coverArtistLabel.textAlignment = .center
        coverArtistLabel.lineBreakMode = .byTruncatingTail
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

        progressTrack.backgroundColor = UIColor(white: 0.80, alpha: 1.0)
        progressTrack.layer.cornerRadius = 4
        progressTrack.layer.borderWidth = 0.8
        progressTrack.layer.borderColor = UIColor(white: 0.60, alpha: 1.0).cgColor
        progressTrack.clipsToBounds = true
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingContainer.addSubview(progressTrack)

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)
        progressWidthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)

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

            coverCollectionView.topAnchor.constraint(equalTo: coverFlowContainer.topAnchor, constant: 8),
            coverCollectionView.leadingAnchor.constraint(equalTo: coverFlowContainer.leadingAnchor),
            coverCollectionView.trailingAnchor.constraint(equalTo: coverFlowContainer.trailingAnchor),
            coverCollectionView.heightAnchor.constraint(equalToConstant: 130),

            coverTitleLabel.topAnchor.constraint(equalTo: coverCollectionView.bottomAnchor, constant: 2),
            coverTitleLabel.leadingAnchor.constraint(equalTo: coverFlowContainer.leadingAnchor, constant: 14),
            coverTitleLabel.trailingAnchor.constraint(equalTo: coverFlowContainer.trailingAnchor, constant: -14),

            coverArtistLabel.topAnchor.constraint(equalTo: coverTitleLabel.bottomAnchor, constant: 2),
            coverArtistLabel.leadingAnchor.constraint(equalTo: coverTitleLabel.leadingAnchor),
            coverArtistLabel.trailingAnchor.constraint(equalTo: coverTitleLabel.trailingAnchor),

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

            progressTrack.leadingAnchor.constraint(equalTo: nowPlayingContainer.leadingAnchor, constant: 12),
            progressTrack.trailingAnchor.constraint(equalTo: nowPlayingContainer.trailingAnchor, constant: -12),
            progressTrack.bottomAnchor.constraint(equalTo: elapsedLabel.topAnchor, constant: -4),
            progressTrack.heightAnchor.constraint(equalToConstant: 9),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressWidthConstraint,

            elapsedLabel.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            elapsedLabel.bottomAnchor.constraint(equalTo: nowPlayingContainer.bottomAnchor, constant: -8),

            remainingLabel.trailingAnchor.constraint(equalTo: progressTrack.trailingAnchor),
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

    func showSongsCoverFlow(title: String, tracks: [IPodTrack], selectedIndex: Int = 0) {
        headerTitleLabel.text = title
        self.coverTracks = tracks
        self.selectedIndex = min(max(0, selectedIndex), max(0, tracks.count - 1))
        self.isCoverFlowActive = true
        nowPlayingContainer.isHidden = true
        tableView.isHidden = true
        coverFlowContainer.isHidden = false
        layoutIfNeeded()
        coverCollectionView.reloadData()

        if !tracks.isEmpty {
            let indexPath = IndexPath(item: self.selectedIndex, section: 0)
            coverCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            updateCoverFlowCaption(for: self.selectedIndex)
            DispatchQueue.main.async {
                self.applyCoverFlowTransforms()
            }
        } else {
            coverTitleLabel.text = "Tidak ada lagu"
            coverArtistLabel.text = "Sinkronkan lagu ke Music/Documents"
        }
    }

    func moveSelection(by delta: Int) {
        guard nowPlayingContainer.isHidden else { return }

        if isCoverFlowActive {
            guard !coverTracks.isEmpty else { return }
            let next = min(max(0, selectedIndex + delta), coverTracks.count - 1)
            if next != selectedIndex {
                selectedIndex = next
                let indexPath = IndexPath(item: selectedIndex, section: 0)
                coverCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
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

        for cell in coverCollectionView.visibleCells {
            let distance = cell.center.x - centerX
            let normalized = max(-1.0, min(1.0, distance / 110.0))

            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 450.0
            let angle = -normalized * (.pi / 3.2) // Miring ke dalam menghadap tengah seperti Cover Flow
            let scale = 1.0 - (abs(normalized) * 0.16)
            transform = CATransform3DRotate(transform, angle, 0, 1, 0)
            transform = CATransform3DScale(transform, scale, scale, 1.0)
            cell.layer.transform = transform
            cell.layer.zPosition = 100 - abs(distance)
        }
    }

    func showNowPlaying(track: IPodTrack, index: Int, total: Int) {
        headerTitleLabel.text = "Now Playing"
        tableView.isHidden = true
        coverFlowContainer.isHidden = true
        isCoverFlowActive = false
        nowPlayingContainer.isHidden = false

        trackIndexLabel.text = "\(index + 1) of \(total)"
        trackTitleLabel.text = track.title
        trackArtistLabel.text = track.artist
        trackAlbumLabel.text = track.album
        artworkView.image = track.artworkImage ?? makeDefaultNoteArtwork()
    }

    func updateProgress(elapsed: TimeInterval, duration: TimeInterval) {
        let safeDur = max(duration, 1.0)
        let ratio = CGFloat(min(max(elapsed / safeDur, 0.0), 1.0))
        progressWidthConstraint.constant = progressTrack.bounds.width * ratio
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

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == selectedIndex {
            onCoverFlowTrackSelected?(indexPath.item)
        } else {
            selectedIndex = indexPath.item
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            updateCoverFlowCaption(for: selectedIndex)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === coverCollectionView else { return }
        applyCoverFlowTransforms()

        let centerX = coverCollectionView.contentOffset.x + coverCollectionView.bounds.width / 2.0
        var closestIndex = selectedIndex
        var minDistance = CGFloat.greatestFiniteMagnitude

        for cell in coverCollectionView.visibleCells {
            if let idx = coverCollectionView.indexPath(for: cell)?.item {
                let d = abs(cell.center.x - centerX)
                if d < minDistance {
                    minDistance = d
                    closestIndex = idx
                }
            }
        }
        if closestIndex != selectedIndex {
            selectedIndex = closestIndex
            updateCoverFlowCaption(for: selectedIndex)
        }
    }
}