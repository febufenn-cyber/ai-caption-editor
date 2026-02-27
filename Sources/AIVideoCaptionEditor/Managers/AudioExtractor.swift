import AVFoundation
import Foundation

enum AudioExtractorError: Error {
    case missingAudioTrack
    case readerFailed
    case wavReadFailed
}

actor AudioExtractor {
    func extractMono16kPCM(
        from videoURL: URL,
        progress: @escaping @Sendable (Double) -> Void,
        isCancelled: @escaping @Sendable () -> Bool
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioExtractorError.missingAudioTrack
        }

        let durationCM = try await asset.load(.duration)
        let duration = max(durationCM.seconds, 0.001)

        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw AudioExtractorError.readerFailed
        }
        reader.add(output)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-\(UUID().uuidString).wav")

        let writer = try WAVWriter(url: tempURL, sampleRate: 16_000, channels: 1, bitsPerSample: 16)

        reader.startReading()

        while reader.status == .reading {
            if isCancelled() {
                reader.cancelReading()
                break
            }

            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                break
            }

            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                var totalLength = 0
                var dataPointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(
                    blockBuffer,
                    atOffset: 0,
                    lengthAtOffsetOut: nil,
                    totalLengthOut: &totalLength,
                    dataPointerOut: &dataPointer
                )

                if let dataPointer {
                    try writer.append(bytes: UnsafeRawPointer(dataPointer), count: totalLength)
                }
            }

            let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            progress(min(max(ts / duration, 0), 1))
        }

        try writer.finalize()

        if reader.status == .failed {
            throw reader.error ?? AudioExtractorError.readerFailed
        }

        progress(1)
        return tempURL
    }

    func waveform(fromWAV wavURL: URL, sampleCount: Int) throws -> [Float] {
        let data = try Data(contentsOf: wavURL)
        guard data.count > 44 else {
            throw AudioExtractorError.wavReadFailed
        }

        let payload = data.dropFirst(44)
        let int16Count = payload.count / MemoryLayout<Int16>.size
        guard int16Count > 0 else {
            return Array(repeating: 0, count: sampleCount)
        }

        return payload.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            let bucketSize = max(1, samples.count / max(sampleCount, 1))
            var buckets = [Float]()
            buckets.reserveCapacity(sampleCount)

            var index = 0
            while index < samples.count {
                let upper = min(samples.count, index + bucketSize)
                var peak: Float = 0
                for value in samples[index..<upper] {
                    peak = max(peak, abs(Float(value)) / Float(Int16.max))
                }
                buckets.append(peak)
                index += bucketSize
            }

            if buckets.count < sampleCount {
                buckets.append(contentsOf: Array(repeating: 0, count: sampleCount - buckets.count))
            }
            return Array(buckets.prefix(sampleCount))
        }
    }
}
