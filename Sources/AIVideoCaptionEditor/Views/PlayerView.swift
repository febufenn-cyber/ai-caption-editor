import AVKit
import SwiftUI

struct NativePlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.showsSharingServiceButton = false
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct PlayerPane: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if viewModel.videoPlayerManager.loadedURL != nil {
                NativePlayerView(player: viewModel.videoPlayerManager.player)
                    .overlay {
                        CaptionOverlayMetalView(viewModel: viewModel)
                            .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.45))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 28, weight: .semibold))
                            Text("Drop an MP4/MOV file to start")
                                .font(.headline)
                        }
                        .foregroundStyle(Color.white.opacity(0.8))
                    }
            }

            HStack(spacing: 14) {
                Label(Timecode.format(viewModel.videoPlayerManager.currentTime), systemImage: "clock")
                Label("\(Int(viewModel.videoPlayerManager.resolution.width))×\(Int(viewModel.videoPlayerManager.resolution.height))", systemImage: "rectangle.3.group")
                Label(String(format: "%.2f fps", viewModel.videoPlayerManager.frameRate), systemImage: "speedometer")
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(12)
        }
    }
}
