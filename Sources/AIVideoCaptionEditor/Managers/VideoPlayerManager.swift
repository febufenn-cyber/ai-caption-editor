import AVFoundation
import AppKit
import Combine

@MainActor
final class VideoPlayerManager: ObservableObject {
    @Published private(set) var player = AVPlayer()
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var frameRate: Double = 30
    @Published private(set) var resolution: CGSize = .zero
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var loadedURL: URL?

    private var periodicObserver: Any?

    init() {
        configurePlayer()
    }

    func load(url: URL) async throws {
        loadedURL = url
        let asset = AVURLAsset(url: url)

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoPlayerManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"]) 
        }

        let fps = try await track.load(.nominalFrameRate)
        let naturalSize = try await track.load(.naturalSize)
        let durationCM = try await asset.load(.duration)

        duration = max(durationCM.seconds, 0)
        frameRate = fps > 0 ? Double(fps) : 30
        resolution = naturalSize

        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 1.5
        player.replaceCurrentItem(with: item)
        player.automaticallyWaitsToMinimizeStalling = true
        currentTime = 0
        isPlaying = false
    }

    func playPauseToggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        let safeTime = max(0, min(time, duration))
        let cm = CMTime(seconds: safeTime, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = safeTime
    }

    func stepFrame(forward: Bool) {
        let step = 1 / max(frameRate, 1)
        pause()
        seek(to: currentTime + (forward ? step : -step))
    }

    private func configurePlayer() {
        periodicObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 60.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                self.isPlaying = self.player.rate != 0
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
    }
}
