import AppKit
import Foundation

struct AnimatedCaptionFrame {
    var attributedText: NSAttributedString
    var alpha: Double
    var scale: CGFloat
    var yOffset: CGFloat
}

struct CaptionAnimationEngine {
    func frame(
        for caption: Caption,
        style: CaptionStyle,
        time: TimeInterval
    ) -> AnimatedCaptionFrame {
        let clamped = max(caption.startTime, min(caption.endTime, time))
        let progress = caption.duration > 0 ? (clamped - caption.startTime) / caption.duration : 1
        let attributes = baseAttributes(style: style)

        switch style.animation {
        case .fade:
            let alpha = smoothStep(progress, edge0: 0, edge1: 0.15) * smoothStep(1 - progress, edge0: 0, edge1: 0.2)
            return AnimatedCaptionFrame(
                attributedText: NSAttributedString(string: caption.text, attributes: attributes),
                alpha: alpha,
                scale: 1,
                yOffset: 0
            )

        case .pop:
            let eased = easeOutBack(progress)
            return AnimatedCaptionFrame(
                attributedText: NSAttributedString(string: caption.text, attributes: attributes),
                alpha: 1,
                scale: max(0.6, eased),
                yOffset: 0
            )

        case .slideUp:
            let yOffset = CGFloat((1 - smoothStep(progress, edge0: 0, edge1: 0.2)) * -28)
            return AnimatedCaptionFrame(
                attributedText: NSAttributedString(string: caption.text, attributes: attributes),
                alpha: 1,
                scale: 1,
                yOffset: yOffset
            )

        case .typewriter:
            let visibleCount = Int(Double(caption.text.count) * smoothStep(progress, edge0: 0, edge1: 1))
            let text = String(caption.text.prefix(max(1, visibleCount)))
            return AnimatedCaptionFrame(
                attributedText: NSAttributedString(string: text, attributes: attributes),
                alpha: 1,
                scale: 1,
                yOffset: 0
            )

        case .karaoke:
            return AnimatedCaptionFrame(
                attributedText: karaokeAttributedText(caption: caption, style: style, time: clamped),
                alpha: 1,
                scale: 1,
                yOffset: 0
            )
        }
    }

    private func baseAttributes(style: CaptionStyle) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        switch style.alignment {
        case .leading:
            paragraph.alignment = .left
        case .center:
            paragraph.alignment = .center
        case .trailing:
            paragraph.alignment = .right
        }

        let shadow = NSShadow()
        shadow.shadowBlurRadius = style.shadowRadius
        shadow.shadowColor = style.shadowColor.nsColor
        shadow.shadowOffset = NSSize(width: style.shadowOffsetX, height: style.shadowOffsetY)

        return [
            .font: style.nsFont,
            .foregroundColor: style.textColor.nsColor,
            .strokeColor: style.strokeColor.nsColor,
            .strokeWidth: -style.strokeWidth,
            .shadow: shadow,
            .paragraphStyle: paragraph
        ]
    }

    private func karaokeAttributedText(caption: Caption, style: CaptionStyle, time: TimeInterval) -> NSAttributedString {
        let base = NSMutableAttributedString(
            string: caption.text,
            attributes: baseAttributes(style: style)
        )

        guard !caption.words.isEmpty else {
            return base
        }

        let highlightColor = NSColor(calibratedRed: 1, green: 0.86, blue: 0.18, alpha: 1)
        var searchStart = caption.text.startIndex

        for word in caption.words {
            guard time >= word.startTime else { break }
            if let foundRange = caption.text.range(
                of: word.text,
                options: .caseInsensitive,
                range: searchStart..<caption.text.endIndex
            ) {
                let nsRange = NSRange(foundRange, in: caption.text)
                base.addAttribute(.foregroundColor, value: highlightColor, range: nsRange)
                searchStart = foundRange.upperBound
            }
        }

        return base
    }

    private func smoothStep(_ value: Double, edge0: Double, edge1: Double) -> Double {
        let t = max(0, min(1, (value - edge0) / max(0.0001, edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private func easeOutBack(_ value: Double) -> CGFloat {
        let c1 = 1.70158
        let c3 = c1 + 1
        let x = value - 1
        return CGFloat(1 + c3 * pow(x, 3) + c1 * pow(x, 2))
    }
}
