import Foundation
import Combine

@MainActor
final class TimelineController: ObservableObject {
    @Published var zoom: Double = 1
    @Published var selectedCaptionID: UUID?
    @Published var speechPausePoints: [TimeInterval] = []

    func pixelsPerSecond(base: Double = 140) -> Double {
        base * zoom
    }

    func xPosition(for time: TimeInterval) -> Double {
        max(0, time) * pixelsPerSecond()
    }

    func time(for xPosition: Double) -> TimeInterval {
        max(0, xPosition / max(pixelsPerSecond(), 1))
    }

    func move(captionID: UUID, deltaTime: TimeInterval, in model: CaptionModel) {
        model.mutateCaption(id: captionID) { caption in
            let newStart = max(0, caption.startTime + deltaTime)
            let newEnd = max(newStart + 0.05, caption.endTime + deltaTime)
            caption.startTime = snap(time: newStart)
            caption.endTime = snap(time: newEnd)
        }
    }

    func resizeLeading(captionID: UUID, deltaTime: TimeInterval, in model: CaptionModel) {
        model.mutateCaption(id: captionID) { caption in
            let candidate = min(caption.endTime - 0.05, caption.startTime + deltaTime)
            caption.startTime = snap(time: max(0, candidate))
        }
    }

    func resizeTrailing(captionID: UUID, deltaTime: TimeInterval, in model: CaptionModel) {
        model.mutateCaption(id: captionID) { caption in
            let candidate = max(caption.startTime + 0.05, caption.endTime + deltaTime)
            caption.endTime = snap(time: candidate)
        }
    }

    func updateSpeechPauses(from captions: [Caption]) {
        let sorted = captions.sorted { $0.startTime < $1.startTime }
        var pauses: [TimeInterval] = []

        for idx in 1..<sorted.count {
            let gapStart = sorted[idx - 1].endTime
            let gapEnd = sorted[idx].startTime
            if gapEnd - gapStart >= 0.12 {
                pauses.append((gapStart + gapEnd) * 0.5)
            }
        }

        speechPausePoints = pauses
    }

    private func snap(time: TimeInterval, threshold: TimeInterval = 0.08) -> TimeInterval {
        if let nearest = speechPausePoints.min(by: { abs($0 - time) < abs($1 - time) }), abs(nearest - time) <= threshold {
            return nearest
        }
        return time
    }
}
