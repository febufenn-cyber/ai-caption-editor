import Foundation

struct CaptionWord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
}
