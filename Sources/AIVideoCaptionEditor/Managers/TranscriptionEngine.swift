import Foundation

enum TranscriptionUpdate {
    case status(String)
    case progress(Double)
    case partial(Caption)
    case finished(captions: [Caption], wavURL: URL)
    case cancelled
    case failed(String)
}

struct WhisperSegment {
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var words: [CaptionWord]

    var caption: Caption {
        Caption(
            text: text,
            startTime: startTime,
            endTime: endTime,
            words: words,
            styleOverride: nil
        )
    }
}

enum WhisperBackendError: Error {
    case cliNotFound
    case modelNotFound
    case failed(String)
}

private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var remainder = Data()

    func consume(chunk: Data, onLine: (String) -> Void) {
        lock.lock()
        remainder.append(chunk)
        while let newlineIndex = remainder.firstIndex(of: 0x0A) {
            let lineData = remainder.prefix(upTo: newlineIndex)
            remainder.removeSubrange(...newlineIndex)
            if let line = String(data: lineData, encoding: .utf8) {
                onLine(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        lock.unlock()
    }
}

private final class CaptionCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Caption] = []

    func append(_ caption: Caption) {
        lock.lock()
        storage.append(caption)
        lock.unlock()
    }

    func values() -> [Caption] {
        lock.lock()
        let values = storage
        lock.unlock()
        return values.sorted { $0.startTime < $1.startTime }
    }
}

final class WhisperCLIBackend: @unchecked Sendable {
    private let fileManager = FileManager.default

    func transcribe(
        audioURL: URL,
        modelURL: URL?,
        token: CancellationToken,
        onProgress: @escaping @Sendable (Double) -> Void,
        onSegment: @escaping @Sendable (WhisperSegment) -> Void
    ) throws {
        guard let cliURL = resolveCLIPath() else {
            throw WhisperBackendError.cliNotFound
        }

        let resolvedModel = try resolveModelPath(explicitModelURL: modelURL)

        let process = Process()
        process.executableURL = cliURL
        process.arguments = [
            "-m", resolvedModel.path,
            "-f", audioURL.path,
            "-l", "auto",
            "-pp",
            "-nt"
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutBuffer = LineBuffer()
        let stderrBuffer = LineBuffer()

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }

            stdoutBuffer.consume(chunk: chunk) { line in
                if let segment = Self.parseSegment(from: line) {
                    onSegment(segment)
                }
                if let progress = Self.parseProgress(from: line) {
                    onProgress(progress)
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }

            stderrBuffer.consume(chunk: chunk) { line in
                if let progress = Self.parseProgress(from: line) {
                    onProgress(progress)
                }
            }
        }

        try process.run()

        while process.isRunning {
            if token.isCancelled {
                process.terminate()
                break
            }
            Thread.sleep(forTimeInterval: 0.08)
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if token.isCancelled {
            throw CancellationError()
        }

        if process.terminationStatus != 0 {
            throw WhisperBackendError.failed("whisper-cli exited with code \(process.terminationStatus)")
        }

        onProgress(1)
    }

    private func resolveCLIPath() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "./ThirdParty/whisper.cpp/build/bin/whisper-cli"),
            URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli"),
            URL(fileURLWithPath: "/usr/local/bin/whisper-cli")
        ]

        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) })
    }

    private func resolveModelPath(explicitModelURL: URL?) throws -> URL {
        if let explicitModelURL {
            return explicitModelURL
        }

        let searchPaths = [
            URL(fileURLWithPath: "./Models/ggml-base.en.bin"),
            URL(fileURLWithPath: "./Models/ggml-small.en.bin"),
            URL(fileURLWithPath: "./ThirdParty/whisper.cpp/models/ggml-base.en.bin"),
            URL(fileURLWithPath: "/opt/homebrew/share/whisper/models/ggml-base.en.bin")
        ]

        if let found = searchPaths.first(where: { fileManager.fileExists(atPath: $0.path) }) {
            return found
        }

        throw WhisperBackendError.modelNotFound
    }

    private static func parseProgress(from line: String) -> Double? {
        guard let percentRange = line.range(of: #"(\d{1,3})%"#, options: .regularExpression) else {
            return nil
        }

        let value = line[percentRange].replacingOccurrences(of: "%", with: "")
        guard let intValue = Double(value) else { return nil }
        return min(max(intValue / 100, 0), 1)
    }

    private static func parseSegment(from line: String) -> WhisperSegment? {
        let pattern = #"\[(\d\d:\d\d:\d\d\.\d\d\d)\s*-->\s*(\d\d:\d\d:\d\d\.\d\d\d)\]\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range), match.numberOfRanges == 4 else {
            return nil
        }

        guard
            let startRange = Range(match.range(at: 1), in: line),
            let endRange = Range(match.range(at: 2), in: line),
            let textRange = Range(match.range(at: 3), in: line)
        else {
            return nil
        }

        let start = parseTimestamp(String(line[startRange]))
        let end = parseTimestamp(String(line[endRange]))
        let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)

        guard end > start, !text.isEmpty else {
            return nil
        }

        let words = tokenizeWords(text: text, startTime: start, endTime: end)
        return WhisperSegment(text: text, startTime: start, endTime: end, words: words)
    }

    private static func parseTimestamp(_ value: String) -> TimeInterval {
        let parts = value.split(separator: ":")
        guard parts.count == 3 else { return 0 }
        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let secParts = parts[2].split(separator: ".")
        let seconds = Double(secParts.first ?? "0") ?? 0
        let millis = secParts.count > 1 ? (Double(secParts[1]) ?? 0) / 1000 : 0
        return hours * 3600 + minutes * 60 + seconds + millis
    }

    private static func tokenizeWords(text: String, startTime: TimeInterval, endTime: TimeInterval) -> [CaptionWord] {
        let tokens = text.split(whereSeparator: { $0.isWhitespace })
        guard !tokens.isEmpty else { return [] }

        let span = max(0.01, endTime - startTime)
        let unit = span / Double(tokens.count)

        return tokens.enumerated().map { idx, token in
            let start = startTime + (Double(idx) * unit)
            let end = min(endTime, start + unit)
            return CaptionWord(text: String(token), startTime: start, endTime: end)
        }
    }
}

final class TranscriptionEngine {
    private let audioExtractor = AudioExtractor()
    private let backend = WhisperCLIBackend()

    private var activeTask: Task<Void, Never>?
    private var token = CancellationToken()

    func start(
        videoURL: URL,
        modelURL: URL?,
        onUpdate: @escaping @MainActor (TranscriptionUpdate) -> Void
    ) {
        cancel()
        token = CancellationToken()

        let collector = CaptionCollector()

        activeTask = Task.detached(priority: .userInitiated) { [audioExtractor, backend, token] in
            await onUpdate(.status("Extracting audio"))
            do {
                let wavURL = try await audioExtractor.extractMono16kPCM(
                    from: videoURL,
                    progress: { value in
                        Task { @MainActor in
                            onUpdate(.progress(value * 0.35))
                        }
                    },
                    isCancelled: {
                        token.isCancelled
                    }
                )

                await onUpdate(.status("Transcribing with whisper.cpp"))

                try backend.transcribe(
                    audioURL: wavURL,
                    modelURL: modelURL,
                    token: token,
                    onProgress: { progress in
                        Task { @MainActor in
                            onUpdate(.progress(0.35 + progress * 0.65))
                        }
                    },
                    onSegment: { segment in
                        collector.append(segment.caption)
                        Task { @MainActor in
                            onUpdate(.partial(segment.caption))
                        }
                    }
                )

                await onUpdate(.finished(captions: collector.values(), wavURL: wavURL))
            } catch is CancellationError {
                await onUpdate(.cancelled)
            } catch {
                await onUpdate(.failed(error.localizedDescription))
            }
        }
    }

    func cancel() {
        token.cancel()
        activeTask?.cancel()
        activeTask = nil
    }
}
