import Foundation

enum Timecode {
    static func format(_ value: TimeInterval) -> String {
        let safe = max(0, value)
        let hours = Int(safe / 3600)
        let minutes = Int((safe.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(safe.truncatingRemainder(dividingBy: 60))
        let millis = Int((safe - floor(safe)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
    }

    static func parse(_ value: String) -> TimeInterval? {
        let comps = value.split(separator: ":")
        guard comps.count == 3 else { return nil }
        guard let hours = Double(comps[0]), let minutes = Double(comps[1]) else { return nil }
        let secParts = comps[2].split(separator: ".")
        guard let seconds = Double(secParts[0]) else { return nil }
        let millis = secParts.count > 1 ? (Double(secParts[1]) ?? 0) / 1000 : 0
        return hours * 3600 + minutes * 60 + seconds + millis
    }
}
