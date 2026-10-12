import Foundation
import UIKit
import ModSettings

public enum ModTypingStyle: String, CaseIterable {
    case none
    case bounce
    case jump
    case wave
    case pop
    case drop
    case slideUp
    case slideSide
    case rotate
    case rubber
    case shake
    case fade
    case glow
    case rainbow

    public var title: String {
        switch self {
        case .none: return "Выключено"
        case .bounce: return "Подпрыгивание"
        case .jump: return "Прыжок"
        case .wave: return "Волна"
        case .pop: return "Всплытие"
        case .drop: return "Падение сверху"
        case .slideUp: return "Выезд снизу"
        case .slideSide: return "Выезд сбоку"
        case .rotate: return "Вращение"
        case .rubber: return "Резинка"
        case .shake: return "Тряска"
        case .fade: return "Проявление"
        case .glow: return "Неон"
        case .rainbow: return "Радуга"
        }
    }

    public static var current: ModTypingStyle {
        return ModTypingStyle(rawValue: ModSettings.typingStyle) ?? .none
    }
}

/// Animates each newly typed character of a text input: the real glyph is hidden with a
/// mask hole while a copy of it (a label) plays the selected animation on top of it.
public final class ModTypingAnimator {
    public static let shared = ModTypingAnimator()

    private final class MaskState {
        let layer = CAShapeLayer()
        var holes: [Int: CGRect] = [:]
    }

    private weak var lastView: UIView?
    private var lastLength: Int = 0
    private var nextHoleId: Int = 0
    private let maskStates = NSMapTable<UIView, MaskState>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    private init() {
    }

    /// Call after every text change of an input. `inputView` is any view containing the text
    /// view (it is searched for a `UITextInput`), `selectedRange` is the caret after the change.
    public func textDidChange(inputView: UIView, attributedText: NSAttributedString?, selectedRange: NSRange) {
        let text = attributedText ?? NSAttributedString()
        let newLength = text.length
        let previousLength = self.lastLength
        let sameView = self.lastView === inputView
        self.lastView = inputView
        self.lastLength = newLength

        let style = ModTypingStyle.current
        if !sameView || style == .none {
            return
        }
        let delta = newLength - previousLength
        if delta <= 0 || delta > 16 || selectedRange.length != 0 {
            return
        }
        let start = selectedRange.location - delta
        if start < 0 || selectedRange.location > newLength {
            return
        }
        let range = NSRange(location: start, length: delta)
        let inserted = text.attributedSubstring(from: range)
        if inserted.string.count != 1 || inserted.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        var hasEmbeddedItem = false
        inserted.enumerateAttributes(in: NSRange(location: 0, length: inserted.length), options: []) { attributes, _, _ in
            for key in attributes.keys {
                if key == .attachment || key.rawValue.contains("CustomEmoji") {
                    hasEmbeddedItem = true
                }
            }
        }
        if hasEmbeddedItem {
            return
        }
        guard let textView = self.findTextInput(in: inputView) else {
            return
        }
        self.animate(style: style, textView: textView, range: range, glyph: inserted)
    }

    private func findTextInput(in view: UIView) -> (UIView & UITextInput)? {
        var queue: [UIView] = [view]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if let textInput = current as? (UIView & UITextInput) {
                return textInput
            }
            queue.append(contentsOf: current.subviews)
        }
        return nil
    }

    private func animate(style: ModTypingStyle, textView: UIView & UITextInput, range: NSRange, glyph: NSAttributedString) {
        guard let startPosition = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let endPosition = textView.position(from: startPosition, offset: range.length),
              let textRange = textView.textRange(from: startPosition, to: endPosition) else {
            return
        }
        // Make sure offsets of this text input map to the same characters.
        if textView.text(in: textRange) != glyph.string {
            return
        }
        let glyphRect = textView.firstRect(for: textRange)
        let caretRect = textView.caretRect(for: startPosition)
        if glyphRect.isNull || glyphRect.isInfinite || glyphRect.width < 0.5 || glyphRect.height < 0.5 {
            return
        }
        if caretRect.isNull || caretRect.isInfinite || caretRect.height < 0.5 {
            return
        }
        let host: UIView = textView.superview ?? textView

        // Hide the real glyph.
        guard let holeId = self.addHole(view: textView, rect: glyphRect) else {
            return
        }

        let labelRect = CGRect(x: glyphRect.minX, y: caretRect.minY, width: glyphRect.width, height: caretRect.height)
        let label = self.makeLabel(glyph: glyph, textView: textView)
        label.frame = textView.convert(labelRect, to: host)
        host.addSubview(label)

        let duration = max(0.1, min(1.5, ModSettings.typingDuration))
        let k = CGFloat(max(0.25, min(2.0, ModSettings.typingIntensity)))
        let height = labelRect.height
        var totalDuration = duration

        switch style {
        case .none:
            break
        case .bounce:
            totalDuration = duration * 1.6
            label.transform = CGAffineTransform(translationX: 0.0, y: height * 0.5 * k)
            label.alpha = 0.3
            UIView.animate(withDuration: totalDuration, delay: 0.0, usingSpringWithDamping: 0.35, initialSpringVelocity: 0.8, options: [.allowUserInteraction], animations: {
                label.transform = .identity
                label.alpha = 1.0
            })
        case .jump:
            totalDuration = duration * 1.3
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
            animation.values = [0.0, -height * 0.55 * k, 0.0, -height * 0.15 * k, 0.0]
            animation.keyTimes = [0.0, 0.35, 0.7, 0.85, 1.0]
            animation.duration = totalDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            label.layer.add(animation, forKey: "modTyping")
        case .wave:
            totalDuration = duration * 1.3
            let translation = CAKeyframeAnimation(keyPath: "transform.translation.y")
            translation.values = [0.0, -height * 0.4 * k, height * 0.1 * k, 0.0]
            translation.keyTimes = [0.0, 0.4, 0.75, 1.0]
            let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            rotation.values = [0.0, -0.35 * k, 0.2 * k, 0.0]
            rotation.keyTimes = [0.0, 0.4, 0.75, 1.0]
            let group = CAAnimationGroup()
            group.animations = [translation, rotation]
            group.duration = totalDuration
            label.layer.add(group, forKey: "modTyping")
        case .pop:
            totalDuration = duration * 1.4
            label.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            UIView.animate(withDuration: totalDuration, delay: 0.0, usingSpringWithDamping: 0.45, initialSpringVelocity: 0.5, options: [.allowUserInteraction], animations: {
                label.transform = .identity
            })
        case .drop:
            totalDuration = duration * 1.5
            label.transform = CGAffineTransform(translationX: 0.0, y: -height * 0.9 * k)
            label.alpha = 0.0
            UIView.animate(withDuration: totalDuration, delay: 0.0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.3, options: [.allowUserInteraction], animations: {
                label.transform = .identity
                label.alpha = 1.0
            })
        case .slideUp:
            label.transform = CGAffineTransform(translationX: 0.0, y: height * 0.7 * k)
            label.alpha = 0.0
            UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
                label.transform = .identity
                label.alpha = 1.0
            })
        case .slideSide:
            totalDuration = duration * 1.3
            label.transform = CGAffineTransform(translationX: -height * 0.8 * k, y: 0.0)
            label.alpha = 0.0
            UIView.animate(withDuration: totalDuration, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: [.allowUserInteraction], animations: {
                label.transform = .identity
                label.alpha = 1.0
            })
        case .rotate:
            totalDuration = duration * 1.4
            label.transform = CGAffineTransform(rotationAngle: -.pi / 2.0 * k).scaledBy(x: 0.3, y: 0.3)
            label.alpha = 0.0
            UIView.animate(withDuration: totalDuration, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3, options: [.allowUserInteraction], animations: {
                label.transform = .identity
                label.alpha = 1.0
            })
        case .rubber:
            totalDuration = duration * 1.6
            label.transform = CGAffineTransform(scaleX: 1.0 + 0.6 * k, y: max(0.1, 1.0 - 0.4 * k))
            UIView.animate(withDuration: totalDuration, delay: 0.0, usingSpringWithDamping: 0.3, initialSpringVelocity: 0.5, options: [.allowUserInteraction], animations: {
                label.transform = .identity
            })
        case .shake:
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
            let amplitude = height * 0.25 * k
            animation.values = [0.0, -amplitude, amplitude, -amplitude * 0.6, amplitude * 0.6, -amplitude * 0.3, 0.0]
            animation.duration = duration
            label.layer.add(animation, forKey: "modTyping")
        case .fade:
            label.alpha = 0.0
            UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseIn, .allowUserInteraction], animations: {
                label.alpha = 1.0
            })
        case .glow:
            let glowColor = (label.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor) ?? UIColor.white
            label.layer.shadowColor = glowColor.cgColor
            label.layer.shadowOffset = .zero
            label.layer.shadowRadius = 8.0 * k
            label.layer.shadowOpacity = 1.0
            label.transform = CGAffineTransform(scaleX: 1.0 + 0.3 * k, y: 1.0 + 0.3 * k)
            let shadow = CABasicAnimation(keyPath: "shadowOpacity")
            shadow.fromValue = 1.0
            shadow.toValue = 0.0
            shadow.duration = duration
            label.layer.shadowOpacity = 0.0
            label.layer.add(shadow, forKey: "modTypingGlow")
            UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
                label.transform = .identity
            })
        case .rainbow:
            let colored = self.makeLabel(glyph: glyph, textView: textView)
            colored.textColor = UIColor(hue: CGFloat.random(in: 0.0 ..< 1.0), saturation: 0.85, brightness: 1.0, alpha: 1.0)
            colored.frame = label.bounds
            label.addSubview(colored)
            label.transform = CGAffineTransform(scaleX: 1.0 + 0.4 * k, y: 1.0 + 0.4 * k)
            UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
                label.transform = .identity
                colored.alpha = 0.0
            })
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.05) { [weak self, weak textView] in
            label.removeFromSuperview()
            if let self, let textView {
                self.removeHole(view: textView, id: holeId)
            }
        }
    }

    private func makeLabel(glyph: NSAttributedString, textView: UIView) -> UILabel {
        let label = UILabel()
        label.isUserInteractionEnabled = false
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.clipsToBounds = false
        let mutableGlyph = NSMutableAttributedString(attributedString: glyph)
        let fullRange = NSRange(location: 0, length: mutableGlyph.length)
        if glyph.attribute(.foregroundColor, at: 0, effectiveRange: nil) == nil, let color = (textView as? UITextView)?.textColor {
            mutableGlyph.addAttribute(.foregroundColor, value: color, range: fullRange)
        }
        if glyph.attribute(.font, at: 0, effectiveRange: nil) == nil, let font = (textView as? UITextView)?.font {
            mutableGlyph.addAttribute(.font, value: font, range: fullRange)
        }
        // Paragraph styles of the input would shift the glyph inside the label.
        mutableGlyph.removeAttribute(.paragraphStyle, range: fullRange)
        label.attributedText = mutableGlyph
        return label
    }

    // MARK: Glyph hiding

    private func addHole(view: UIView, rect: CGRect) -> Int? {
        let state: MaskState
        if let current = self.maskStates.object(forKey: view) {
            state = current
        } else {
            state = MaskState()
            state.layer.fillRule = .evenOdd
            state.layer.fillColor = UIColor.black.cgColor
            self.maskStates.setObject(state, forKey: view)
        }
        if let mask = view.layer.mask, mask !== state.layer {
            // The view has its own mask, don't break it.
            return nil
        }
        let id = self.nextHoleId
        self.nextHoleId += 1
        state.holes[id] = rect
        self.updateMask(view: view, state: state)
        return id
    }

    private func removeHole(view: UIView, id: Int) {
        guard let state = self.maskStates.object(forKey: view) else {
            return
        }
        state.holes.removeValue(forKey: id)
        self.updateMask(view: view, state: state)
    }

    private func updateMask(view: UIView, state: MaskState) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if state.holes.isEmpty {
            if view.layer.mask === state.layer {
                view.layer.mask = nil
            }
        } else {
            let bounds = view.bounds
            state.layer.frame = bounds
            let path = UIBezierPath(rect: CGRect(x: -10000.0, y: -10000.0, width: 20000.0 + bounds.width, height: 20000.0 + bounds.height))
            for (_, hole) in state.holes {
                path.append(UIBezierPath(rect: hole.offsetBy(dx: -bounds.minX, dy: -bounds.minY)))
            }
            state.layer.path = path.cgPath
            if view.layer.mask !== state.layer {
                view.layer.mask = state.layer
            }
        }
        CATransaction.commit()
    }
}
