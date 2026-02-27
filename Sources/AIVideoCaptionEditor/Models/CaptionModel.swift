import Foundation
import Combine

@MainActor
final class CaptionModel: ObservableObject {
    @Published private(set) var captions: [Caption] = []

    func replace(with newCaptions: [Caption]) {
        captions = newCaptions.sorted { $0.startTime < $1.startTime }
    }

    func clear() {
        captions = []
    }

    func append(_ caption: Caption) {
        captions.append(caption)
        captions.sort { $0.startTime < $1.startTime }
    }

    func update(_ caption: Caption) {
        guard let idx = captions.firstIndex(where: { $0.id == caption.id }) else {
            append(caption)
            return
        }
        captions[idx] = caption
        captions.sort { $0.startTime < $1.startTime }
    }

    func mutateCaption(id: UUID, _ mutate: (inout Caption) -> Void) {
        guard let idx = captions.firstIndex(where: { $0.id == id }) else { return }
        mutate(&captions[idx])
        if captions[idx].endTime < captions[idx].startTime {
            captions[idx].endTime = captions[idx].startTime + 0.1
        }
        captions.sort { $0.startTime < $1.startTime }
    }

    func activeCaption(at time: TimeInterval) -> Caption? {
        captions.first(where: { $0.contains(time: time) })
    }
}
