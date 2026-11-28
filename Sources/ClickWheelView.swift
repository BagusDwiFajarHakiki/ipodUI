import UIKit
import AudioToolbox

protocol ClickWheelDelegate: AnyObject {
    func clickWheelDidScroll(steps: Int)
    func clickWheelDidPressMenu()
    func clickWheelDidPressSelect()
    func clickWheelDidLongPressSelect()
    func clickWheelDidPressPlayPause()
    func clickWheelDidPressNext()
    func clickWheelDidPressPrevious()
}

class ClickWheelView: UIView {
    weak var delegate: ClickWheelDelegate?

    private let wheelLayer = CAShapeLayer()
    private let timerRingContainerLayer = CALayer()
    private let timerTicksLayer = CAShapeLayer()
    private let timerTrackLayer = CAShapeLayer()
    private let timerArcLayer = CAShapeLayer()

    private let centerButton = UIButton(type: .custom)
    private let timerCenterContainer = UIView()
    private let timerIconView = UIImageView()
    private let timerTimeLabel = UILabel()
    private var timerIconCenterYConstraint: NSLayoutConstraint!
    private var timerIconWidthConstraint: NSLayoutConstraint!
    private var timerIconHeightConstraint: NSLayoutConstraint!

    private let menuLabel = UILabel()
    private let nextIconView = UIImageView()
    private let prevIconView = UIImageView()
    private let playPauseIconView = UIImageView()

    private var currentTheme: IPodColorTheme = .darkPod
    private var sleepSetMinutes: Int = 0
    private var sleepElapsedSeconds: Int = 0
    private var isSleepTimerActive: Bool = false
    private var isTimerEditingMode: Bool = false
    private var isTimerOverlayVisible: Bool = false
    private var timerOverlayToken: Int = 0
    private var didTriggerCenterLongPress = false

    private var lastAngle: CGFloat?
    private var accumulatedAngle: CGFloat = 0
    private var didScrollDuringTouch = false
    private let stepThreshold: CGFloat = 0.30

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupWheel()
        applyTheme(.darkPod)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupWheel() {
        wheelLayer.lineWidth = 0
        wheelLayer.strokeColor = nil
        wheelLayer.shadowColor = UIColor.black.cgColor
        wheelLayer.shadowOpacity = 0.32
        wheelLayer.shadowOffset = CGSize(width: 0, height: 4)
        wheelLayer.shadowRadius = 8
        layer.addSublayer(wheelLayer)

        timerRingContainerLayer.isHidden = true
        timerRingContainerLayer.opacity = 0.0
        layer.addSublayer(timerRingContainerLayer)

        timerTicksLayer.fillColor = UIColor.clear.cgColor
        timerTicksLayer.lineCap = .round
        timerRingContainerLayer.addSublayer(timerTicksLayer)

        timerTrackLayer.fillColor = UIColor.clear.cgColor
        timerTrackLayer.lineWidth = 4.5
        timerRingContainerLayer.addSublayer(timerTrackLayer)

        timerArcLayer.fillColor = UIColor.clear.cgColor
        timerArcLayer.lineWidth = 4.5
        timerArcLayer.lineCap = .round
        timerArcLayer.strokeStart = 0.0
        timerArcLayer.strokeEnd = 0.0
        timerRingContainerLayer.addSublayer(timerArcLayer)

        menuLabel.text = "MENU"
        menuLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .heavy)
        menuLabel.textAlignment = .center
        addSubview(menuLabel)

        nextIconView.image = makeNextIcon(size: CGSize(width: 24, height: 14))
        nextIconView.contentMode = .scaleAspectFit
        addSubview(nextIconView)

        prevIconView.image = makePrevIcon(size: CGSize(width: 24, height: 14))
        prevIconView.contentMode = .scaleAspectFit
        addSubview(prevIconView)

        playPauseIconView.image = makePlayPauseIcon(size: CGSize(width: 26, height: 14))
        playPauseIconView.contentMode = .scaleAspectFit
        addSubview(playPauseIconView)

        centerButton.layer.borderWidth = 0
        centerButton.layer.borderColor = nil
        centerButton.addTarget(self, action: #selector(didTouchDownCenter), for: .touchDown)
        centerButton.addTarget(self, action: #selector(didTapCenter), for: .touchUpInside)
        let centerLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCenterLongPress(_:)))
        centerLongPress.minimumPressDuration = 0.42
        centerLongPress.allowableMovement = 16
        centerButton.addGestureRecognizer(centerLongPress)
        addSubview(centerButton)

        timerCenterContainer.isUserInteractionEnabled = false
        timerCenterContainer.isHidden = true
        timerCenterContainer.alpha = 0.0
        timerCenterContainer.translatesAutoresizingMaskIntoConstraints = false
        centerButton.addSubview(timerCenterContainer)

        timerIconView.image = makeCircularTimerIcon(size: CGSize(width: 34, height: 34))
        timerIconView.contentMode = .scaleAspectFit
        timerIconView.isUserInteractionEnabled = false
        timerIconView.translatesAutoresizingMaskIntoConstraints = false
        timerCenterContainer.addSubview(timerIconView)

        timerTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 19.0, weight: .bold)
        timerTimeLabel.textAlignment = .center
        timerTimeLabel.adjustsFontSizeToFitWidth = true
        timerTimeLabel.minimumScaleFactor = 0.65
        timerTimeLabel.isUserInteractionEnabled = false
        timerTimeLabel.alpha = 0.0
        timerTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        timerCenterContainer.addSubview(timerTimeLabel)

        timerIconCenterYConstraint = timerIconView.centerYAnchor.constraint(equalTo: timerCenterContainer.centerYAnchor)
        timerIconWidthConstraint = timerIconView.widthAnchor.constraint(equalToConstant: 32)
        timerIconHeightConstraint = timerIconView.heightAnchor.constraint(equalToConstant: 32)

        NSLayoutConstraint.activate([
            timerCenterContainer.topAnchor.constraint(equalTo: centerButton.topAnchor),
            timerCenterContainer.bottomAnchor.constraint(equalTo: centerButton.bottomAnchor),
            timerCenterContainer.leadingAnchor.constraint(equalTo: centerButton.leadingAnchor),
            timerCenterContainer.trailingAnchor.constraint(equalTo: centerButton.trailingAnchor),

            timerIconView.centerXAnchor.constraint(equalTo: timerCenterContainer.centerXAnchor),
            timerIconCenterYConstraint,
            timerIconWidthConstraint,
            timerIconHeightConstraint,

            timerTimeLabel.centerXAnchor.constraint(equalTo: timerCenterContainer.centerXAnchor),
            timerTimeLabel.centerYAnchor.constraint(equalTo: timerCenterContainer.centerYAnchor, constant: 9),
            timerTimeLabel.leadingAnchor.constraint(equalTo: timerCenterContainer.leadingAnchor, constant: 8),
            timerTimeLabel.trailingAnchor.constraint(equalTo: timerCenterContainer.trailingAnchor, constant: -8)
        ])
    }

    func applyTheme(_ theme: IPodColorTheme) {
        currentTheme = theme
        let iconTint: UIColor
        switch theme {
        case .darkPod:
            wheelLayer.fillColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0).cgColor
            centerButton.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)
            iconTint = UIColor(white: 0.90, alpha: 1.0)

        case .sepiaPod:
            wheelLayer.fillColor = UIColor(red: 0.96, green: 0.93, blue: 0.87, alpha: 1.0).cgColor
            centerButton.backgroundColor = UIColor(red: 0.86, green: 0.80, blue: 0.70, alpha: 1.0)
            iconTint = UIColor(red: 0.34, green: 0.25, blue: 0.16, alpha: 1.0)

        case .classicBlue:
            wheelLayer.fillColor = UIColor(white: 0.96, alpha: 1.0).cgColor
            centerButton.backgroundColor = UIColor(white: 0.84, alpha: 1.0)
            iconTint = UIColor(white: 0.32, alpha: 1.0)
        }

        menuLabel.textColor = iconTint
        nextIconView.tintColor = iconTint
        prevIconView.tintColor = iconTint
        playPauseIconView.tintColor = iconTint
        renderSleepTimer(previousSetMinutes: sleepSetMinutes, animated: false)
    }

    func updateSleepTimer(setMinutes: Int, elapsedSeconds: Int, isActive: Bool, isEditing: Bool) {
        let prevMinutes = sleepSetMinutes
        sleepSetMinutes = setMinutes
        sleepElapsedSeconds = elapsedSeconds
        isSleepTimerActive = isActive
        isTimerEditingMode = isEditing
        renderSleepTimer(previousSetMinutes: prevMinutes, animated: true)
    }

    private func centerButtonTextColor() -> UIColor {
        switch currentTheme {
        case .darkPod:     return UIColor(white: 0.94, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.28, green: 0.19, blue: 0.11, alpha: 1.0)
        case .classicBlue: return UIColor(white: 0.16, alpha: 1.0)
        }
    }

    private func centerButtonIconTintColor() -> UIColor {
        switch currentTheme {
        case .darkPod:     return UIColor(white: 0.78, alpha: 1.0)
        case .sepiaPod:    return UIColor(red: 0.42, green: 0.31, blue: 0.20, alpha: 1.0)
        case .classicBlue: return UIColor(white: 0.34, alpha: 1.0)
        }
    }

    private func formatMMSS(_ sec: Int) -> String {
        let clamped = max(0, sec)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    private func renderSleepTimer(previousSetMinutes: Int, animated: Bool) {
        let accent = currentTheme.highlightTop
        timerTicksLayer.strokeColor = centerButtonIconTintColor().withAlphaComponent(0.32).cgColor
        timerTrackLayer.strokeColor = (currentTheme == .darkPod
            ? UIColor(white: 1.0, alpha: 0.14)
            : UIColor(white: 0.0, alpha: 0.11)).cgColor
        timerArcLayer.strokeColor = accent.cgColor

        if currentTheme == .darkPod {
            timerArcLayer.shadowColor = accent.cgColor
            timerArcLayer.shadowRadius = 6.0
            timerArcLayer.shadowOpacity = (sleepSetMinutes > 0) ? 0.65 : 0.0
            timerArcLayer.shadowOffset = .zero
        } else {
            timerArcLayer.shadowOpacity = 0.0
        }

        let totalSec = max(0, sleepSetMinutes * 60)
        let progressRatio: CGFloat
        let hasConfiguredTime = (sleepSetMinutes > 0)

        if isSleepTimerActive && hasConfiguredTime {
            let clampedElapsed = min(max(0, sleepElapsedSeconds), totalSec)
            let remaining = max(0, totalSec - clampedElapsed)
            timerTimeLabel.text = formatMMSS(remaining)
            timerTimeLabel.textColor = accent
            timerIconView.tintColor = accent
            progressRatio = CGFloat(remaining) / 3600.0
        } else if hasConfiguredTime {
            timerTimeLabel.text = formatMMSS(totalSec)
            timerTimeLabel.textColor = centerButtonTextColor()
            timerIconView.tintColor = centerButtonIconTintColor()
            progressRatio = CGFloat(sleepSetMinutes) / 60.0
        } else {
            timerIconView.tintColor = isTimerEditingMode ? accent : centerButtonIconTintColor()
            progressRatio = 0.0
        }

        // Update center layout between OFF icon and icon + time
        let targetIconY: CGFloat = hasConfiguredTime ? -15.0 : 0.0
        let targetIconSize: CGFloat = hasConfiguredTime ? 16.0 : 32.0
        let targetTimeAlpha: CGFloat = hasConfiguredTime ? 1.0 : 0.0
        if timerIconCenterYConstraint.constant != targetIconY || timerTimeLabel.alpha != targetTimeAlpha {
            timerIconCenterYConstraint.constant = targetIconY
            timerIconWidthConstraint.constant = targetIconSize
            timerIconHeightConstraint.constant = targetIconSize
            if animated && isTimerOverlayVisible {
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                    self.timerCenterContainer.layoutIfNeeded()
                    self.timerTimeLabel.alpha = targetTimeAlpha
                }
            } else {
                timerCenterContainer.layoutIfNeeded()
                timerTimeLabel.alpha = targetTimeAlpha
            }
        }

        let isResettingToOff = (previousSetMinutes > 0 && sleepSetMinutes == 0 && !isSleepTimerActive)
        CATransaction.begin()
        CATransaction.setAnimationDuration(isResettingToOff ? 0.42 : (isSleepTimerActive ? 0.28 : 0.14))
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        timerArcLayer.strokeEnd = min(max(progressRatio, 0.0), 1.0)
        CATransaction.commit()

        // Smooth center button focus border while editing timer
        let targetBorderWidth: CGFloat = isTimerEditingMode ? 1.5 : 0.0
        let targetBorderColor: CGColor = (isTimerEditingMode ? accent.withAlphaComponent(0.75) : UIColor.clear).cgColor
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.24 : 0.0)
        centerButton.layer.borderWidth = targetBorderWidth
        centerButton.layer.borderColor = targetBorderColor
        CATransaction.commit()

        let shouldShowOverlay = isTimerEditingMode || isSleepTimerActive || hasConfiguredTime
        setTimerOverlayVisible(shouldShowOverlay, delayedForNaturalReset: isResettingToOff && !isTimerEditingMode, animated: animated)
    }

    private func setTimerOverlayVisible(_ visible: Bool, delayedForNaturalReset: Bool, animated: Bool) {
        guard visible != isTimerOverlayVisible else { return }
        isTimerOverlayVisible = visible
        timerOverlayToken &+= 1
        let token = timerOverlayToken

        if visible {
            timerCenterContainer.isHidden = false
            timerRingContainerLayer.isHidden = false

            if animated {
                timerCenterContainer.alpha = 0.0
                timerCenterContainer.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
                UIView.animate(
                    withDuration: 0.34,
                    delay: 0,
                    usingSpringWithDamping: 0.84,
                    initialSpringVelocity: 0.18,
                    options: [.curveEaseOut, .beginFromCurrentState]
                ) {
                    guard self.timerOverlayToken == token else { return }
                    self.timerCenterContainer.alpha = 1.0
                    self.timerCenterContainer.transform = .identity
                }

                CATransaction.begin()
                CATransaction.setAnimationDuration(0.32)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
                timerRingContainerLayer.opacity = 1.0
                timerRingContainerLayer.transform = CATransform3DIdentity
                CATransaction.commit()
            } else {
                timerCenterContainer.alpha = 1.0
                timerCenterContainer.transform = .identity
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                timerRingContainerLayer.opacity = 1.0
                timerRingContainerLayer.transform = CATransform3DIdentity
                CATransaction.commit()
            }
        } else {
            let performHideAnimation = { [weak self] in
                guard let self = self, self.timerOverlayToken == token, !self.isTimerOverlayVisible else { return }
                if animated {
                    UIView.animate(
                        withDuration: 0.24,
                        delay: 0,
                        options: [.curveEaseIn, .beginFromCurrentState],
                        animations: {
                            self.timerCenterContainer.alpha = 0.0
                            self.timerCenterContainer.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
                        },
                        completion: { _ in
                            guard self.timerOverlayToken == token, !self.isTimerOverlayVisible else { return }
                            self.timerCenterContainer.isHidden = true
                            self.timerCenterContainer.transform = .identity
                        }
                    )

                    CATransaction.begin()
                    CATransaction.setAnimationDuration(0.24)
                    CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
                    CATransaction.setCompletionBlock {
                        guard self.timerOverlayToken == token, !self.isTimerOverlayVisible else { return }
                        self.timerRingContainerLayer.isHidden = true
                        self.timerRingContainerLayer.transform = CATransform3DIdentity
                    }
                    self.timerRingContainerLayer.opacity = 0.0
                    self.timerRingContainerLayer.transform = CATransform3DMakeScale(0.96, 0.96, 1.0)
                    CATransaction.commit()
                } else {
                    self.timerCenterContainer.alpha = 0.0
                    self.timerCenterContainer.isHidden = true
                    self.timerCenterContainer.transform = .identity
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.timerRingContainerLayer.opacity = 0.0
                    self.timerRingContainerLayer.isHidden = true
                    self.timerRingContainerLayer.transform = CATransform3DIdentity
                    CATransaction.commit()
                }
            }

            if delayedForNaturalReset && animated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: performHideAnimation)
            } else {
                performHideAnimation()
            }
        }
    }

    private func makeCircularTimerIcon(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let w = size.width
        let h = size.height
        let center = CGPoint(x: w / 2.0, y: h / 2.0 + 1.8)
        let r: CGFloat = min(w, h) * 0.34

        ctx.setLineWidth(2.0)
        ctx.move(to: CGPoint(x: center.x - 3.6, y: center.y - r - 4.4))
        ctx.addLine(to: CGPoint(x: center.x + 3.6, y: center.y - r - 4.4))
        ctx.move(to: CGPoint(x: center.x, y: center.y - r - 4.4))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y - r - 0.8))
        ctx.strokePath()

        ctx.setLineWidth(2.2)
        ctx.addArc(center: center, radius: r, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
        ctx.strokePath()

        ctx.setLineWidth(2.0)
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: center.x, y: center.y - r * 0.56))
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: center.x + r * 0.42, y: center.y + r * 0.16))
        ctx.strokePath()

        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
    }

    private func makeNextIcon(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(UIColor.white.cgColor)
        let h = size.height
        ctx.move(to: CGPoint(x: 2, y: 1))
        ctx.addLine(to: CGPoint(x: 11, y: h / 2))
        ctx.addLine(to: CGPoint(x: 2, y: h - 1))
        ctx.closePath()
        ctx.fillPath()
        ctx.move(to: CGPoint(x: 11, y: 1))
        ctx.addLine(to: CGPoint(x: 20, y: h / 2))
        ctx.addLine(to: CGPoint(x: 11, y: h - 1))
        ctx.closePath()
        ctx.fillPath()
        ctx.fill(CGRect(x: 20.5, y: 1, width: 2.8, height: h - 2))
        let img = UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
        UIGraphicsEndImageContext()
        return img
    }

    private func makePrevIcon(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(UIColor.white.cgColor)
        let h = size.height
        ctx.fill(CGRect(x: 0.7, y: 1, width: 2.8, height: h - 2))
        ctx.move(to: CGPoint(x: 13, y: 1))
        ctx.addLine(to: CGPoint(x: 4, y: h / 2))
        ctx.addLine(to: CGPoint(x: 13, y: h - 1))
        ctx.closePath()
        ctx.fillPath()
        ctx.move(to: CGPoint(x: 22, y: 1))
        ctx.addLine(to: CGPoint(x: 13, y: h / 2))
        ctx.addLine(to: CGPoint(x: 22, y: h - 1))
        ctx.closePath()
        ctx.fillPath()
        let img = UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
        UIGraphicsEndImageContext()
        return img
    }

    private func makePlayPauseIcon(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(UIColor.white.cgColor)
        let h = size.height
        ctx.move(to: CGPoint(x: 2, y: 1))
        ctx.addLine(to: CGPoint(x: 12.5, y: h / 2))
        ctx.addLine(to: CGPoint(x: 2, y: h - 1))
        ctx.closePath()
        ctx.fillPath()
        ctx.fill(CGRect(x: 15.5, y: 1, width: 3.2, height: h - 2))
        ctx.fill(CGRect(x: 20.8, y: 1, width: 3.2, height: h - 2))
        let img = UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
        UIGraphicsEndImageContext()
        return img
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        let wheelRect = CGRect(
            x: (bounds.width - side) / 2.0,
            y: (bounds.height - side) / 2.0,
            width: side,
            height: side
        )
        wheelLayer.path = UIBezierPath(ovalIn: wheelRect).cgPath

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let wheelOuterRadius = side / 2.0
        let timerRingRadius = wheelOuterRadius + 6.5
        let ticksInnerBase = timerRingRadius + 4.5

        let ticksPath = UIBezierPath()
        for i in 0..<60 {
            let angle = (CGFloat(i) / 60.0) * 2.0 * .pi - .pi / 2.0
            let isMajor = (i % 5 == 0)
            let outerTickR = ticksInnerBase + (isMajor ? 4.2 : 2.2)
            ticksPath.move(to: CGPoint(x: center.x + cos(angle) * ticksInnerBase, y: center.y + sin(angle) * ticksInnerBase))
            ticksPath.addLine(to: CGPoint(x: center.x + cos(angle) * outerTickR, y: center.y + sin(angle) * outerTickR))
        }
        timerRingContainerLayer.frame = bounds
        timerTicksLayer.frame = bounds
        timerTicksLayer.lineWidth = 1.15
        timerTicksLayer.path = ticksPath.cgPath

        let ringArcPath = UIBezierPath(
            arcCenter: center,
            radius: timerRingRadius,
            startAngle: -.pi / 2.0,
            endAngle: 1.5 * .pi,
            clockwise: true
        ).cgPath
        timerTrackLayer.frame = bounds
        timerTrackLayer.path = ringArcPath
        timerArcLayer.frame = bounds
        timerArcLayer.path = ringArcPath

        let centerSide = side * 0.36
        centerButton.frame = CGRect(
            x: (bounds.width - centerSide) / 2.0,
            y: (bounds.height - centerSide) / 2.0,
            width: centerSide,
            height: centerSide
        )
        centerButton.layer.cornerRadius = centerSide / 2.0

        let inset = side * 0.14
        menuLabel.frame = CGRect(x: (bounds.width - 70) / 2.0, y: wheelRect.minY + inset - 6, width: 70, height: 20)
        playPauseIconView.frame = CGRect(x: (bounds.width - 26) / 2.0, y: wheelRect.maxY - inset - 11, width: 26, height: 14)
        prevIconView.frame = CGRect(x: wheelRect.minX + inset - 2, y: (bounds.height - 14) / 2.0, width: 24, height: 14)
        nextIconView.frame = CGRect(x: wheelRect.maxX - inset - 22, y: (bounds.height - 14) / 2.0, width: 24, height: 14)
    }

    @objc private func didTouchDownCenter() {
        didTriggerCenterLongPress = false
    }

    @objc private func didTapCenter() {
        if didTriggerCenterLongPress {
            didTriggerCenterLongPress = false
            return
        }
        playClickSound()
        delegate?.clickWheelDidPressSelect()
    }

    @objc private func handleCenterLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            didTriggerCenterLongPress = true
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
            playClickSound()
            delegate?.clickWheelDidLongPressSelect()
        case .ended, .cancelled, .failed:
            DispatchQueue.main.async { [weak self] in
                self?.didTriggerCenterLongPress = false
            }
        default:
            break
        }
    }

    private func playClickSound() {
        AudioServicesPlaySystemSound(1104)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pt = touch.location(in: self)
        if centerButton.frame.contains(pt) { return }
        lastAngle = angle(for: pt)
        accumulatedAngle = 0
        didScrollDuringTouch = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let prevAngle = lastAngle else { return }
        let pt = touch.location(in: self)
        let currentAngle = angle(for: pt)

        var delta = currentAngle - prevAngle
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }

        accumulatedAngle += delta
        lastAngle = currentAngle

        let steps = Int(accumulatedAngle / stepThreshold)
        if steps != 0 {
            didScrollDuringTouch = true
            accumulatedAngle -= CGFloat(steps) * stepThreshold
            playClickSound()
            delegate?.clickWheelDidScroll(steps: steps)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            lastAngle = nil
            accumulatedAngle = 0
        }
        guard !didScrollDuringTouch, let touch = touches.first else { return }
        let pt = touch.location(in: self)
        if centerButton.frame.contains(pt) { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = pt.x - center.x
        let dy = pt.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        let maxR = min(bounds.width, bounds.height) / 2.0
        guard radius <= maxR else { return }

        playClickSound()
        if abs(dx) > abs(dy) {
            if dx > 0 {
                delegate?.clickWheelDidPressNext()
            } else {
                delegate?.clickWheelDidPressPrevious()
            }
        } else {
            if dy < 0 {
                delegate?.clickWheelDidPressMenu()
            } else {
                delegate?.clickWheelDidPressPlayPause()
            }
        }
    }

    private func angle(for point: CGPoint) -> CGFloat {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        return atan2(point.y - center.y, point.x - center.x)
    }
}