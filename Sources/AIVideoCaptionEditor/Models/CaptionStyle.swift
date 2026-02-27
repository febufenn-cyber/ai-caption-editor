import AppKit
import Foundation

enum CaptionAlignment: String, CaseIterable, Codable {
    case leading
    case center
    case trailing
}

enum CaptionAnimationKind: String, CaseIterable, Codable {
    case fade
    case pop
    case slideUp
    case typewriter
    case karaoke
}

struct RGBAColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let resolved = nsColor.usingColorSpace(.deviceRGB) ?? .white
        self.red = Double(resolved.redComponent)
        self.green = Double(resolved.greenComponent)
        self.blue = Double(resolved.blueComponent)
        self.alpha = Double(resolved.alphaComponent)
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let transparent = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
}

struct CaptionStyle: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var fontName: String
    var fontSize: Double
    var textColor: RGBAColor
    var strokeColor: RGBAColor
    var strokeWidth: Double
    var shadowColor: RGBAColor
    var shadowRadius: Double
    var shadowOffsetX: Double
    var shadowOffsetY: Double
    var backgroundColor: RGBAColor
    var backgroundPadding: Double
    var alignment: CaptionAlignment
    var safeMarginX: Double
    var safeMarginY: Double
    var animation: CaptionAnimationKind

    var nsFont: NSFont {
        NSFont(name: fontName, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    }

    static let classic = CaptionStyle(
        name: "Classic",
        fontName: "Avenir Next Bold",
        fontSize: 44,
        textColor: .white,
        strokeColor: .black,
        strokeWidth: 4,
        shadowColor: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.35),
        shadowRadius: 4,
        shadowOffsetX: 0,
        shadowOffsetY: -1,
        backgroundColor: .transparent,
        backgroundPadding: 22,
        alignment: .center,
        safeMarginX: 64,
        safeMarginY: 74,
        animation: .fade
    )

    static let boldSocial = CaptionStyle(
        name: "Bold Social",
        fontName: "Helvetica Neue Bold",
        fontSize: 56,
        textColor: RGBAColor(red: 1, green: 0.92, blue: 0.2, alpha: 1),
        strokeColor: .black,
        strokeWidth: 6,
        shadowColor: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.4),
        shadowRadius: 6,
        shadowOffsetX: 0,
        shadowOffsetY: -2,
        backgroundColor: RGBAColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 0.45),
        backgroundPadding: 26,
        alignment: .center,
        safeMarginX: 40,
        safeMarginY: 60,
        animation: .pop
    )

    static let karaoke = CaptionStyle(
        name: "Karaoke",
        fontName: "Gill Sans Bold",
        fontSize: 48,
        textColor: .white,
        strokeColor: RGBAColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1),
        strokeWidth: 4,
        shadowColor: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.3),
        shadowRadius: 8,
        shadowOffsetX: 0,
        shadowOffsetY: -2,
        backgroundColor: RGBAColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 0.3),
        backgroundPadding: 20,
        alignment: .center,
        safeMarginX: 40,
        safeMarginY: 52,
        animation: .karaoke
    )

    static let minimalFilm = CaptionStyle(
        name: "Minimal Film",
        fontName: "Times New Roman Bold",
        fontSize: 40,
        textColor: RGBAColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1),
        strokeColor: RGBAColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
        strokeWidth: 2,
        shadowColor: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.2),
        shadowRadius: 3,
        shadowOffsetX: 0,
        shadowOffsetY: -1,
        backgroundColor: .transparent,
        backgroundPadding: 18,
        alignment: .center,
        safeMarginX: 84,
        safeMarginY: 88,
        animation: .slideUp
    )
}
