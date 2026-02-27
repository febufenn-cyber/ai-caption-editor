import AppKit
import CoreImage
import Metal

final class CaptionRenderer: @unchecked Sendable {
    private let animationEngine = CaptionAnimationEngine()
    private let context: CIContext

    init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        if let device {
            context = CIContext(mtlDevice: device, options: [
                .cacheIntermediates: false,
                .useSoftwareRenderer: false
            ])
        } else {
            context = CIContext(options: [
                .cacheIntermediates: false,
                .useSoftwareRenderer: false
            ])
        }
    }

    func ciContext() -> CIContext {
        context
    }

    func overlayImage(
        caption: Caption?,
        style: CaptionStyle,
        time: TimeInterval,
        canvasSize: CGSize
    ) -> CIImage {
        guard let caption, caption.contains(time: time) else {
            return clearImage(size: canvasSize)
        }

        let frame = animationEngine.frame(for: caption, style: style, time: time)
        let image = NSImage(size: canvasSize)
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

        let maxWidth = max(40, canvasSize.width - (style.safeMarginX * 2))
        let textBounds = frame.attributedText.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let x: CGFloat
        switch style.alignment {
        case .leading:
            x = style.safeMarginX
        case .center:
            x = (canvasSize.width - textBounds.width) * 0.5
        case .trailing:
            x = canvasSize.width - style.safeMarginX - textBounds.width
        }

        let y = style.safeMarginY + frame.yOffset
        let textRect = CGRect(
            x: x,
            y: y,
            width: min(maxWidth, textBounds.width + 4),
            height: textBounds.height + 4
        )

        if style.backgroundColor.alpha > 0.01 {
            style.backgroundColor.nsColor.setFill()
            let backgroundRect = textRect.insetBy(dx: -style.backgroundPadding, dy: -style.backgroundPadding * 0.5)
            let path = NSBezierPath(roundedRect: backgroundRect, xRadius: 12, yRadius: 12)
            path.fill()
        }

        frame.attributedText.draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        image.unlockFocus()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return clearImage(size: canvasSize)
        }

        var ciImage = CIImage(cgImage: cgImage)

        if abs(frame.scale - 1) > 0.001 {
            let center = CGPoint(x: textRect.midX, y: textRect.midY)
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .scaledBy(x: frame.scale, y: frame.scale)
                .translatedBy(x: -center.x, y: -center.y)
            ciImage = ciImage.transformed(by: transform)
        }

        if frame.alpha < 0.999 {
            ciImage = ciImage.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: frame.alpha)
                ]
            )
        }

        return ciImage.cropped(to: CGRect(origin: .zero, size: canvasSize))
    }

    func composite(
        sourceImage: CIImage,
        captions: [Caption],
        styleProvider: (Caption) -> CaptionStyle,
        time: TimeInterval
    ) -> CIImage {
        let canvasSize = sourceImage.extent.size
        guard let active = captions.first(where: { $0.contains(time: time) }) else {
            return sourceImage
        }

        let style = styleProvider(active)
        let overlay = overlayImage(
            caption: active,
            style: style,
            time: time,
            canvasSize: canvasSize
        )

        return overlay.composited(over: sourceImage)
    }

    private func clearImage(size: CGSize) -> CIImage {
        CIImage(color: .clear).cropped(to: CGRect(origin: .zero, size: size))
    }
}
