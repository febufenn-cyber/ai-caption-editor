import Foundation
import Combine

@MainActor
final class StyleManager: ObservableObject {
    @Published var globalStyle: CaptionStyle = .classic
    @Published private(set) var presets: [String: CaptionStyle] = [:]

    init() {
        presets = [
            CaptionStyle.classic.name: .classic,
            CaptionStyle.boldSocial.name: .boldSocial,
            CaptionStyle.karaoke.name: .karaoke,
            CaptionStyle.minimalFilm.name: .minimalFilm
        ]
    }

    var presetNames: [String] {
        presets.keys.sorted()
    }

    func applyPreset(named name: String) {
        guard let style = presets[name] else { return }
        globalStyle = style
    }

    func style(for caption: Caption) -> CaptionStyle {
        caption.styleOverride ?? globalStyle
    }

    func setOverride(_ style: CaptionStyle?, captionID: UUID, in model: CaptionModel) {
        model.mutateCaption(id: captionID) { caption in
            caption.styleOverride = style
        }
    }
}
