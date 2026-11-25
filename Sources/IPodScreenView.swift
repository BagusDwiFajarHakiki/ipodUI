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

class IPodScreenView: UIView, UITableViewDataSource, UITableViewDelegate {
    var theme: IPodColorTheme = .sepiaPod {
        didSet { applyTheme() }
    }

    // Top Status Bar
    private let headerBar = UIView()
    private let headerBorder = UIView()
    private let playStateIcon = UILabel()
    private let headerTitleLabel = UILabel()
    private let batteryView = UIView()
    private let batteryFill = UIView()

    // Menu View
    private let tableView = UITableView()
    private var rows: [IPodMenuRow] = []
    private(set) var selectedIndex: Int = 0

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

        headerTitleLabel.text = "SepiaPod"
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

    private func applyTheme() {
        backgroundColor = theme.screenBackground
        headerBar.backgroundColor = theme == .sepiaPod
            ? UIColor(red: 0.90, green: 0.84, blue: 0.72, alpha: 1.0)
            : UIColor(white: 0.90, alpha: 1.0)
        headerTitleLabel.textColor = theme.primaryText
        playStateIcon.textColor = theme.highlightBottom
        trackIndexLabel.textColor = theme.secondaryText
        trackTitleLabel.textColor = theme.primaryText
        trackArtistLabel.textColor = theme.secondaryText
        trackAlbumLabel.textColor = theme.secondaryText
        elapsedLabel.textColor = theme.primaryText
        remainingLabel.textColor = theme.primaryText
        progressFill.backgroundColor = theme.highlightTop
        tableView.reloadData()
    }

    func updatePlayState(isPlaying: Bool) {
        playStateIcon.text = isPlaying ? "▶" : "❚❚"
    }

    func showMenu(title: String, items: [IPodMenuRow], selectedIndex: Int = 0) {
        headerTitleLabel.text = title
        self.rows = items
        self.selectedIndex = min(max(0, selectedIndex), max(0, items.count - 1))
        nowPlayingContainer.isHidden = true
        tableView.isHidden = false
        tableView.reloadData()
        if !rows.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: self.selectedIndex, section: 0), at: .none, animated: false)
        }
    }

    func moveSelection(by delta: Int) {
        guard nowPlayingContainer.isHidden, !rows.isEmpty else { return }
        let next = min(max(0, selectedIndex + delta), rows.count - 1)
        if next != selectedIndex {
            selectedIndex = next
            tableView.reloadData()
            tableView.scrollToRow(at: IndexPath(row: selectedIndex, section: 0), at: .none, animated: false)
        }
    }

    func showNowPlaying(track: IPodTrack, index: Int, total: Int) {
        headerTitleLabel.text = "Now Playing"
        tableView.isHidden = true
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
        let size = CGSize(width: 120, height: 120)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        theme.highlightTop.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
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
}