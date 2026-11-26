import UIKit
import AudioToolbox

protocol ClickWheelDelegate: AnyObject {
    func clickWheelDidScroll(steps: Int)
    func clickWheelDidPressMenu()
    func clickWheelDidPressSelect()
    func clickWheelDidPressPlayPause()
    func clickWheelDidPressNext()
    func clickWheelDidPressPrevious()
}

class ClickWheelView: UIView {
    weak var delegate: ClickWheelDelegate?

    private let wheelLayer = CAShapeLayer()
    private let centerButton = UIButton(type: .custom)
    private let menuLabel = UILabel()
    private let nextIconView = UIImageView()
    private let prevIconView = UIImageView()
    private let playPauseIconView = UIImageView()

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
        centerButton.addTarget(self, action: #selector(didTapCenter), for: .touchUpInside)
        addSubview(centerButton)
    }

    func applyTheme(_ theme: IPodColorTheme) {
        let iconTint: UIColor
        switch theme {
        case .darkPod:
            wheelLayer.fillColor = UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0).cgColor
            centerButton.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
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

    @objc private func didTapCenter() {
        playClickSound()
        delegate?.clickWheelDidPressSelect()
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