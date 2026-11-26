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
    private let nextLabel = UILabel()
    private let prevLabel = UILabel()
    private let playPauseLabel = UILabel()

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
        wheelLayer.lineWidth = 1.5
        wheelLayer.shadowColor = UIColor.black.cgColor
        wheelLayer.shadowOpacity = 0.32
        wheelLayer.shadowOffset = CGSize(width: 0, height: 4)
        wheelLayer.shadowRadius = 8
        layer.addSublayer(wheelLayer)

        menuLabel.text = "MENU"
        menuLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        menuLabel.textAlignment = .center
        addSubview(menuLabel)

        nextLabel.text = "▶▶|"
        nextLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        nextLabel.textAlignment = .center
        addSubview(nextLabel)

        prevLabel.text = "|◀◀"
        prevLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        prevLabel.textAlignment = .center
        addSubview(prevLabel)

        playPauseLabel.text = "▶❚❚"
        playPauseLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        playPauseLabel.textAlignment = .center
        addSubview(playPauseLabel)

        centerButton.layer.borderWidth = 1.0
        centerButton.addTarget(self, action: #selector(didTapCenter), for: .touchUpInside)
        addSubview(centerButton)
    }

    func applyTheme(_ theme: IPodColorTheme) {
        switch theme {
        case .darkPod:
            wheelLayer.fillColor = UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0).cgColor
            wheelLayer.strokeColor = UIColor(white: 0.24, alpha: 1.0).cgColor
            centerButton.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
            centerButton.layer.borderColor = UIColor(white: 0.22, alpha: 1.0).cgColor
            let textCol = UIColor(white: 0.78, alpha: 1.0)
            menuLabel.textColor = textCol
            nextLabel.textColor = textCol
            prevLabel.textColor = textCol
            playPauseLabel.textColor = textCol

        case .sepiaPod:
            wheelLayer.fillColor = UIColor(red: 0.96, green: 0.93, blue: 0.87, alpha: 1.0).cgColor
            wheelLayer.strokeColor = UIColor(red: 0.80, green: 0.74, blue: 0.64, alpha: 1.0).cgColor
            centerButton.backgroundColor = UIColor(red: 0.86, green: 0.80, blue: 0.70, alpha: 1.0)
            centerButton.layer.borderColor = UIColor(red: 0.75, green: 0.68, blue: 0.58, alpha: 1.0).cgColor
            let textCol = UIColor(red: 0.42, green: 0.33, blue: 0.23, alpha: 1.0)
            menuLabel.textColor = textCol
            nextLabel.textColor = textCol
            prevLabel.textColor = textCol
            playPauseLabel.textColor = textCol

        case .classicBlue:
            wheelLayer.fillColor = UIColor(white: 0.96, alpha: 1.0).cgColor
            wheelLayer.strokeColor = UIColor(white: 0.78, alpha: 1.0).cgColor
            centerButton.backgroundColor = UIColor(white: 0.84, alpha: 1.0)
            centerButton.layer.borderColor = UIColor(white: 0.74, alpha: 1.0).cgColor
            let textCol = UIColor(white: 0.45, alpha: 1.0)
            menuLabel.textColor = textCol
            nextLabel.textColor = textCol
            prevLabel.textColor = textCol
            playPauseLabel.textColor = textCol
        }
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
        playPauseLabel.frame = CGRect(x: (bounds.width - 70) / 2.0, y: wheelRect.maxY - inset - 14, width: 70, height: 20)
        prevLabel.frame = CGRect(x: wheelRect.minX + inset - 10, y: (bounds.height - 20) / 2.0, width: 44, height: 20)
        nextLabel.frame = CGRect(x: wheelRect.maxX - inset - 34, y: (bounds.height - 20) / 2.0, width: 44, height: 20)
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