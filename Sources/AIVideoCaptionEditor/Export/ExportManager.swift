import AVFoundation
import Foundation

enum ExportCodec: String, CaseIterable {
    case h264
    case hevc

    var fileType: AVFileType {
        switch self {
        case .h264:
            return .mp4
        case .hevc:
            return .mov
        }
    }

    var preset: String {
        switch self {
        case .h264:
            return AVAssetExportPresetHighestQuality
        case .hevc:
            if #available(macOS 11.0, *) {
                return AVAssetExportPresetHEVCHighestQuality
            } else {
                return AVAssetExportPresetHighestQuality
            }
        }
    }
}

enum ExportError: Error {
    case noVideoTrack
    case cannotCreateSession
    case failed
}

actor ExportManager {
    private let renderer = CaptionRenderer()
    private var activeExportSession: AVAssetExportSession?

    func cancel() {
        activeExportSession?.cancelExport()
        activeExportSession = nil
    }

    func export(
        assetURL: URL,
        captions: [Caption],
        globalStyle: CaptionStyle,
        outputURL: URL,
        codec: ExportCodec,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: assetURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.noVideoTrack
        }

        let nominalFps = try await videoTrack.load(.nominalFrameRate)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let transformed = naturalSize.applying(preferredTransform)
        let renderSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))

        let composition = AVMutableVideoComposition(asset: asset) { [renderer] request in
            autoreleasepool {
                let time = request.compositionTime.seconds
                let image = renderer.composite(
                    sourceImage: request.sourceImage,
                    captions: captions,
                    styleProvider: { caption in
                        caption.styleOverride ?? globalStyle
                    },
                    time: time
                )
                request.finish(with: image, context: nil)
            }
        }

        composition.renderSize = renderSize
        composition.renderScale = 1
        composition.frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(max(1, Int32(nominalFps > 0 ? nominalFps.rounded() : 30)))
        )

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let session = AVAssetExportSession(asset: asset, presetName: codec.preset) else {
            throw ExportError.cannotCreateSession
        }

        session.videoComposition = composition
        session.outputURL = outputURL
        session.outputFileType = codec.fileType
        session.shouldOptimizeForNetworkUse = false
        activeExportSession = session

        session.exportAsynchronously {}

        while session.status == .waiting || session.status == .exporting {
            await progress(Double(session.progress))
            try? await Task.sleep(for: .milliseconds(120))
        }

        await progress(1)
        activeExportSession = nil

        switch session.status {
        case .completed:
            return
        case .cancelled:
            throw CancellationError()
        default:
            throw session.error ?? ExportError.failed
        }
    }
}
