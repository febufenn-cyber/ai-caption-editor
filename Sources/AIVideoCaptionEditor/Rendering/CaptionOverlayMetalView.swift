import Metal
@preconcurrency import MetalKit
import SwiftUI

struct CaptionOverlayMetalView: NSViewRepresentable {
    @ObservedObject var viewModel: EditorViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        context.coordinator.makeView()
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let currentTime = viewModel.videoPlayerManager.currentTime
        let active = viewModel.captionModel.activeCaption(at: currentTime)
        let style = active.map { viewModel.styleManager.style(for: $0) } ?? viewModel.styleManager.globalStyle

        context.coordinator.snapshot = RenderSnapshot(
            activeCaption: active,
            style: style,
            currentTime: currentTime
        )
    }

    struct RenderSnapshot {
        var activeCaption: Caption?
        var style: CaptionStyle
        var currentTime: TimeInterval

        static let empty = RenderSnapshot(
            activeCaption: nil,
            style: .classic,
            currentTime: 0
        )
    }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate {
        private let device = MTLCreateSystemDefaultDevice()
        private lazy var commandQueue = device?.makeCommandQueue()
        private lazy var renderer = CaptionRenderer(device: device)
        private let colorSpace = CGColorSpaceCreateDeviceRGB()

        var snapshot = RenderSnapshot.empty

        func makeView() -> MTKView {
            let mtkView = MTKView(frame: .zero, device: device)
            mtkView.framebufferOnly = false
            mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            mtkView.enableSetNeedsDisplay = false
            mtkView.isPaused = false
            mtkView.preferredFramesPerSecond = 60
            mtkView.delegate = self
            return mtkView
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            _ = size
        }

        func draw(in view: MTKView) {
            guard
                let drawable = view.currentDrawable,
                let commandQueue,
                let commandBuffer = commandQueue.makeCommandBuffer()
            else {
                return
            }

            let size = CGSize(width: view.drawableSize.width, height: view.drawableSize.height)
            let overlay = renderer.overlayImage(
                caption: snapshot.activeCaption,
                style: snapshot.style,
                time: snapshot.currentTime,
                canvasSize: size
            )

            renderer.ciContext().render(
                overlay,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: .zero, size: size),
                colorSpace: colorSpace
            )

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
