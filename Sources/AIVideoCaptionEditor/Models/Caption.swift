import Foundation

struct Caption: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var words: [CaptionWord]
    var styleOverride: CaptionStyle?

    var duration: TimeInterval {
        max(0, endTime - startTime)
    }

    func contains(time: TimeInterval) -> Bool {
        time >= startTime && time <= endTime
    }
}
