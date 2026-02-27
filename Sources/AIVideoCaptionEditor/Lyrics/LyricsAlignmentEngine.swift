import Foundation

struct LyricsAlignmentEngine {
    func segmentLyrics(_ lyrics: String) -> [String] {
        lyrics
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func suggestAlignment(
        lyrics: String,
        speechCaptions: [Caption],
        trackDuration: TimeInterval
    ) -> [Caption] {
        let lyricSegments = segmentLyrics(lyrics)
        guard !lyricSegments.isEmpty else { return [] }

        let rhythmDurations = speechCaptions.map(\.duration).filter { $0 > 0.05 }
        let fallbackDuration = max(0.5, trackDuration / Double(lyricSegments.count))

        var cursor: TimeInterval = 0
        var generated: [Caption] = []

        for (index, line) in lyricSegments.enumerated() {
            let rhythm = rhythmDurations.isEmpty ? fallbackDuration : rhythmDurations[index % rhythmDurations.count]
            let duration = max(0.45, rhythm)
            let start = min(cursor, max(0, trackDuration - duration))
            let end = min(trackDuration, start + duration)
            let words = makeWordTiming(text: line, startTime: start, endTime: end)
            generated.append(
                Caption(
                    text: line,
                    startTime: start,
                    endTime: end,
                    words: words,
                    styleOverride: nil
                )
            )
            cursor = end + 0.03
        }

        return generated
    }

    func nudge(caption: inout Caption, by seconds: TimeInterval, maxDuration: TimeInterval) {
        let width = caption.duration
        let newStart = max(0, min(maxDuration - width, caption.startTime + seconds))
        caption.startTime = newStart
        caption.endTime = newStart + width
        caption.words = makeWordTiming(text: caption.text, startTime: caption.startTime, endTime: caption.endTime)
    }

    private func makeWordTiming(text: String, startTime: TimeInterval, endTime: TimeInterval) -> [CaptionWord] {
        let tokens = text.split(whereSeparator: { $0.isWhitespace })
        guard !tokens.isEmpty else { return [] }
        let span = max(0.1, endTime - startTime)
        let unit = span / Double(tokens.count)

        return tokens.enumerated().map { idx, token in
            let start = startTime + (Double(idx) * unit)
            return CaptionWord(
                text: String(token),
                startTime: start,
                endTime: min(endTime, start + unit)
            )
        }
    }
}
