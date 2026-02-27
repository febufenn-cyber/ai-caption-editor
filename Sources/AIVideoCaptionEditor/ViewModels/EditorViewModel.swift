import AppKit
import Foundation
import Combine

@MainActor
final class EditorViewModel: ObservableObject {
    let videoPlayerManager = VideoPlayerManager()
    let captionModel = CaptionModel()
    let timelineController = TimelineController()
    let styleManager = StyleManager()

    @Published var transcriptionProgress: Double = 0
    @Published var exportProgress: Double = 0
    @Published var isTranscribing = false
    @Published var isExporting = false
    @Published var statusMessage = "Import a video to begin."
    @Published var waveformSamples: [Float] = Array(repeating: 0, count: 900)
    @Published var lyricsText = ""
    @Published var selectedCodec: ExportCodec = .h264
    @Published var whisperModelURL: URL?

    private let transcriptionEngine = TranscriptionEngine()
    private let lyricsAlignmentEngine = LyricsAlignmentEngine()
    private let audioExtractor = AudioExtractor()
    private let exportManager = ExportManager()

    private var transcriptionCache: [URL: [Caption]] = [:]
    private var waveformCache: [URL: [Float]] = [:]
    private var wavCache: [URL: URL] = [:]

    func importVideo(url: URL) async {
        do {
            try await videoPlayerManager.load(url: url)
            captionModel.clear()
            timelineController.updateSpeechPauses(from: [])
            waveformSamples = Array(repeating: 0, count: waveformSamples.count)
            transcriptionProgress = 0
            statusMessage = "Loaded \(url.lastPathComponent)"

            if let cachedCaptions = transcriptionCache[url] {
                captionModel.replace(with: cachedCaptions)
                timelineController.updateSpeechPauses(from: cachedCaptions)
                statusMessage = "Loaded cached transcription"
            }
            if let cachedWaveform = waveformCache[url] {
                waveformSamples = cachedWaveform
            }
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    func startTranscription() {
        guard let videoURL = videoPlayerManager.loadedURL else {
            statusMessage = "Import a video first"
            return
        }

        if let cached = transcriptionCache[videoURL], !cached.isEmpty {
            captionModel.replace(with: cached)
            timelineController.updateSpeechPauses(from: cached)
            transcriptionProgress = 1
            isTranscribing = false
            statusMessage = "Using cached transcription"
            return
        }

        isTranscribing = true
        transcriptionProgress = 0
        captionModel.clear()
        timelineController.updateSpeechPauses(from: [])

        transcriptionEngine.start(
            videoURL: videoURL,
            modelURL: whisperModelURL,
            onUpdate: { [weak self] update in
                guard let self else { return }
                self.applyTranscription(update: update, sourceURL: videoURL)
            }
        )
    }

    func cancelTranscription() {
        transcriptionEngine.cancel()
        isTranscribing = false
        statusMessage = "Transcription cancelled"
    }

    func applyLyricsAlignment() {
        guard videoPlayerManager.duration > 0 else {
            statusMessage = "Load a video before lyric alignment"
            return
        }

        let generated = lyricsAlignmentEngine.suggestAlignment(
            lyrics: lyricsText,
            speechCaptions: captionModel.captions,
            trackDuration: videoPlayerManager.duration
        )

        guard !generated.isEmpty else {
            statusMessage = "No lyric segments found"
            return
        }

        captionModel.replace(with: generated)
        timelineController.updateSpeechPauses(from: generated)
        statusMessage = "Lyrics aligned"
    }

    func nudgeSelectedCaption(by seconds: TimeInterval) {
        guard let selected = timelineController.selectedCaptionID else { return }
        captionModel.mutateCaption(id: selected) { [lyricsAlignmentEngine, duration = videoPlayerManager.duration] caption in
            lyricsAlignmentEngine.nudge(caption: &caption, by: seconds, maxDuration: duration)
        }
    }

    func selectCaption(_ id: UUID?) {
        timelineController.selectedCaptionID = id
        guard let id, let caption = captionModel.captions.first(where: { $0.id == id }) else { return }
        videoPlayerManager.seek(to: caption.startTime)
    }

    func updateCaptionText(id: UUID, text: String) {
        captionModel.mutateCaption(id: id) { caption in
            caption.text = text
            caption.words = caption.text
                .split(whereSeparator: { $0.isWhitespace })
                .enumerated()
                .map { index, token in
                    let segment = max(0.05, caption.duration / Double(max(1, caption.text.split(whereSeparator: { $0.isWhitespace }).count)))
                    let start = caption.startTime + (Double(index) * segment)
                    return CaptionWord(text: String(token), startTime: start, endTime: min(caption.endTime, start + segment))
                }
        }
    }

    func updateCaptionStart(id: UUID, from timecode: String) {
        guard let parsed = Timecode.parse(timecode) else { return }
        captionModel.mutateCaption(id: id) { caption in
            caption.startTime = max(0, min(parsed, caption.endTime - 0.05))
        }
    }

    func updateCaptionEnd(id: UUID, from timecode: String) {
        guard let parsed = Timecode.parse(timecode) else { return }
        captionModel.mutateCaption(id: id) { caption in
            caption.endTime = max(caption.startTime + 0.05, parsed)
        }
    }

    func createOverrideForSelectedCaption() {
        guard let id = timelineController.selectedCaptionID else { return }
        styleManager.setOverride(styleManager.globalStyle, captionID: id, in: captionModel)
    }

    func clearOverrideForSelectedCaption() {
        guard let id = timelineController.selectedCaptionID else { return }
        styleManager.setOverride(nil, captionID: id, in: captionModel)
    }

    func updateGlobalStyle(_ mutate: (inout CaptionStyle) -> Void) {
        var copy = styleManager.globalStyle
        mutate(&copy)
        styleManager.globalStyle = copy
    }

    func startExport() {
        guard let sourceURL = videoPlayerManager.loadedURL else {
            statusMessage = "Nothing to export"
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "captioned-\(sourceURL.deletingPathExtension().lastPathComponent).\(selectedCodec == .h264 ? "mp4" : "mov")"
        panel.allowedContentTypes = selectedCodec == .h264 ? [.mpeg4Movie] : [.quickTimeMovie]

        guard panel.runModal() == .OK, let destination = panel.url else {
            return
        }

        Task {
            await exportVideo(sourceURL: sourceURL, destinationURL: destination)
        }
    }

    func cancelExport() {
        Task {
            await exportManager.cancel()
        }
        isExporting = false
        statusMessage = "Export cancelled"
    }

    func activeCaption() -> Caption? {
        captionModel.activeCaption(at: videoPlayerManager.currentTime)
    }

    private func exportVideo(sourceURL: URL, destinationURL: URL) async {
        isExporting = true
        exportProgress = 0
        statusMessage = "Exporting..."

        do {
            try await exportManager.export(
                assetURL: sourceURL,
                captions: captionModel.captions,
                globalStyle: styleManager.globalStyle,
                outputURL: destinationURL,
                codec: selectedCodec,
                progress: { [weak self] value in
                    self?.exportProgress = value
                }
            )
            isExporting = false
            exportProgress = 1
            statusMessage = "Export finished: \(destinationURL.lastPathComponent)"
        } catch is CancellationError {
            isExporting = false
            statusMessage = "Export cancelled"
        } catch {
            isExporting = false
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func applyTranscription(update: TranscriptionUpdate, sourceURL: URL) {
        switch update {
        case .status(let message):
            statusMessage = message

        case .progress(let progress):
            transcriptionProgress = progress

        case .partial(let caption):
            upsertPartialCaption(caption)
            timelineController.updateSpeechPauses(from: captionModel.captions)

        case .finished(let captions, let wavURL):
            isTranscribing = false
            transcriptionProgress = 1
            let finalCaptions = captions.isEmpty ? captionModel.captions : captions
            captionModel.replace(with: finalCaptions)
            timelineController.updateSpeechPauses(from: finalCaptions)
            transcriptionCache[sourceURL] = finalCaptions
            wavCache[sourceURL] = wavURL
            statusMessage = "Transcription complete"

            Task {
                do {
                    let waveform = try await audioExtractor.waveform(fromWAV: wavURL, sampleCount: 900)
                    waveformCache[sourceURL] = waveform
                    waveformSamples = waveform
                } catch {
                    statusMessage = "Waveform generation failed"
                }
            }

        case .cancelled:
            isTranscribing = false
            statusMessage = "Transcription cancelled"

        case .failed(let message):
            isTranscribing = false
            statusMessage = "Transcription failed: \(message)"
        }
    }

    private func upsertPartialCaption(_ newCaption: Caption) {
        if let existing = captionModel.captions.first(where: { abs($0.startTime - newCaption.startTime) < 0.08 }) {
            var updated = existing
            updated.text = newCaption.text
            updated.endTime = max(updated.endTime, newCaption.endTime)
            updated.words = newCaption.words
            captionModel.update(updated)
        } else {
            captionModel.append(newCaption)
        }
    }
}
