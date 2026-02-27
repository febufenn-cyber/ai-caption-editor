import Foundation

enum WAVWriterError: Error {
    case cannotCreateFile
    case invalidHeaderPatch
}

final class WAVWriter {
    private let handle: FileHandle
    private let sampleRate: UInt32
    private let channels: UInt16
    private let bitsPerSample: UInt16
    private var dataLength: UInt32 = 0

    init(url: URL, sampleRate: UInt32, channels: UInt16, bitsPerSample: UInt16) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let handle = FileHandle(forWritingAtPath: url.path) else {
            throw WAVWriterError.cannotCreateFile
        }
        self.handle = handle
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        try writePlaceholderHeader()
    }

    deinit {
        try? handle.close()
    }

    func append(bytes: UnsafeRawPointer, count: Int) throws {
        let data = Data(bytes: bytes, count: count)
        try handle.write(contentsOf: data)
        dataLength += UInt32(count)
    }

    func finalize() throws {
        try handle.seek(toOffset: 0)
        let header = try makeHeader(dataLength: dataLength)
        try handle.write(contentsOf: header)
        try handle.close()
    }

    private func writePlaceholderHeader() throws {
        let placeholder = try makeHeader(dataLength: 0)
        try handle.write(contentsOf: placeholder)
    }

    private func makeHeader(dataLength: UInt32) throws -> Data {
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        var header = Data()

        header.append("RIFF".data(using: .ascii)!)
        var chunkSize = UInt32(36 + dataLength)
        header.append(Data(bytes: &chunkSize, count: 4))
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)

        var subchunk1Size: UInt32 = 16
        var audioFormat: UInt16 = 1
        var channelsValue = channels
        var sampleRateValue = sampleRate
        var byteRateValue = byteRate
        var blockAlignValue = blockAlign
        var bits = bitsPerSample

        header.append(Data(bytes: &subchunk1Size, count: 4))
        header.append(Data(bytes: &audioFormat, count: 2))
        header.append(Data(bytes: &channelsValue, count: 2))
        header.append(Data(bytes: &sampleRateValue, count: 4))
        header.append(Data(bytes: &byteRateValue, count: 4))
        header.append(Data(bytes: &blockAlignValue, count: 2))
        header.append(Data(bytes: &bits, count: 2))
        header.append("data".data(using: .ascii)!)

        var payloadSize = dataLength
        header.append(Data(bytes: &payloadSize, count: 4))

        guard header.count == 44 else {
            throw WAVWriterError.invalidHeaderPatch
        }
        return header
    }
}
