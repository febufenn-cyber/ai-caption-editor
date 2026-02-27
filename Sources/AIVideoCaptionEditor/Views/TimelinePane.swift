import SwiftUI

struct TimelinePane: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Timeline")
                    .font(.headline)
                Spacer()
                Text("Zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: zoomBinding, in: 0.4...5)
                    .frame(width: 160)
            }

            GeometryReader { proxy in
                let pps = viewModel.timelineController.pixelsPerSecond()
                let width = max(proxy.size.width, CGFloat(viewModel.videoPlayerManager.duration * pps) + 220)

                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            WaveformView(samples: viewModel.waveformSamples)
                                .frame(width: width, height: 86)

                            Rectangle()
                                .fill(Color.black.opacity(0.36))
                                .frame(width: width, height: 98)
                        }

                        ForEach(viewModel.captionModel.captions) { caption in
                            CaptionTimelineBlock(
                                caption: caption,
                                pixelsPerSecond: pps,
                                isSelected: caption.id == viewModel.timelineController.selectedCaptionID,
                                onSelect: {
                                    viewModel.selectCaption(caption.id)
                                },
                                onMoveDelta: { deltaTime in
                                    viewModel.timelineController.move(
                                        captionID: caption.id,
                                        deltaTime: deltaTime,
                                        in: viewModel.captionModel
                                    )
                                },
                                onLeadingResizeDelta: { deltaTime in
                                    viewModel.timelineController.resizeLeading(
                                        captionID: caption.id,
                                        deltaTime: deltaTime,
                                        in: viewModel.captionModel
                                    )
                                },
                                onTrailingResizeDelta: { deltaTime in
                                    viewModel.timelineController.resizeTrailing(
                                        captionID: caption.id,
                                        deltaTime: deltaTime,
                                        in: viewModel.captionModel
                                    )
                                }
                            )
                            .position(
                                x: CGFloat(viewModel.timelineController.xPosition(for: caption.startTime + (caption.duration / 2))),
                                y: 133
                            )
                        }

                        Rectangle()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: 2, height: 185)
                            .position(
                                x: CGFloat(viewModel.timelineController.xPosition(for: viewModel.videoPlayerManager.currentTime)),
                                y: 92
                            )
                    }
                    .frame(width: width, height: 188)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let targetTime = viewModel.timelineController.time(for: gesture.location.x)
                                viewModel.videoPlayerManager.seek(to: targetTime)
                            }
                    )
                }
            }
            .frame(minHeight: 190)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.22))
        )
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { viewModel.timelineController.zoom },
            set: { viewModel.timelineController.zoom = $0 }
        )
    }
}

private struct CaptionTimelineBlock: View {
    let caption: Caption
    let pixelsPerSecond: Double
    let isSelected: Bool
    let onSelect: () -> Void
    let onMoveDelta: (TimeInterval) -> Void
    let onLeadingResizeDelta: (TimeInterval) -> Void
    let onTrailingResizeDelta: (TimeInterval) -> Void

    @State private var moveTranslation: CGFloat = 0
    @State private var leftTranslation: CGFloat = 0
    @State private var rightTranslation: CGFloat = 0

    var body: some View {
        let width = max(34, CGFloat(caption.duration * pixelsPerSecond))
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.orange.opacity(0.72) : Color.blue.opacity(0.68))
                .frame(width: width, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(isSelected ? 0.88 : 0.36), lineWidth: isSelected ? 2 : 1)
                )

            Text(caption.text)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .foregroundStyle(.white)
                .frame(width: width, alignment: .leading)

            HStack(spacing: 0) {
                handle
                    .gesture(leadingResizeGesture)
                Spacer(minLength: 0)
                handle
                    .gesture(trailingResizeGesture)
            }
            .frame(width: width)
        }
        .frame(width: width, height: 36)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .gesture(moveGesture)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.9))
            .frame(width: 6, height: 30)
            .padding(.horizontal, 2)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let deltaPixels = value.translation.width - moveTranslation
                moveTranslation = value.translation.width
                onMoveDelta(TimeInterval(deltaPixels / max(pixelsPerSecond, 1)))
            }
            .onEnded { _ in
                moveTranslation = 0
            }
    }

    private var leadingResizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let deltaPixels = value.translation.width - leftTranslation
                leftTranslation = value.translation.width
                onLeadingResizeDelta(TimeInterval(deltaPixels / max(pixelsPerSecond, 1)))
            }
            .onEnded { _ in
                leftTranslation = 0
            }
    }

    private var trailingResizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let deltaPixels = value.translation.width - rightTranslation
                rightTranslation = value.translation.width
                onTrailingResizeDelta(TimeInterval(deltaPixels / max(pixelsPerSecond, 1)))
            }
            .onEnded { _ in
                rightTranslation = 0
            }
    }
}
