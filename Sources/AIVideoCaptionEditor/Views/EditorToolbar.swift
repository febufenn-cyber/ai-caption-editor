import SwiftUI

struct EditorToolbar: View {
    @ObservedObject var viewModel: EditorViewModel
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button("Import", systemImage: "square.and.arrow.down") {
                onImport()
            }
            .buttonStyle(.borderedProminent)

            if viewModel.isTranscribing {
                Button("Cancel", systemImage: "xmark.circle") {
                    viewModel.cancelTranscription()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Transcribe", systemImage: "waveform.badge.mic") {
                    viewModel.startTranscription()
                }
                .buttonStyle(.bordered)
            }

            Divider().frame(height: 22)

            Button(action: { viewModel.videoPlayerManager.stepFrame(forward: false) }) {
                Image(systemName: "backward.frame")
            }
            .help("Previous frame")

            Button(action: { viewModel.videoPlayerManager.playPauseToggle() }) {
                Image(systemName: viewModel.videoPlayerManager.isPlaying ? "pause.fill" : "play.fill")
            }
            .help("Play/Pause")

            Button(action: { viewModel.videoPlayerManager.stepFrame(forward: true) }) {
                Image(systemName: "forward.frame")
            }
            .help("Next frame")

            Divider().frame(height: 22)

            Picker("Codec", selection: $viewModel.selectedCodec) {
                Text("H264 MP4").tag(ExportCodec.h264)
                Text("HEVC MOV").tag(ExportCodec.hevc)
            }
            .pickerStyle(.menu)
            .frame(width: 140)

            if viewModel.isExporting {
                Button("Cancel Export", systemImage: "xmark") {
                    viewModel.cancelExport()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Export", systemImage: "square.and.arrow.up") {
                    viewModel.startExport()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                if viewModel.isTranscribing {
                    ProgressView(value: viewModel.transcriptionProgress)
                        .frame(width: 170)
                } else if viewModel.isExporting {
                    ProgressView(value: viewModel.exportProgress)
                        .frame(width: 170)
                }
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.28))
        )
    }
}
