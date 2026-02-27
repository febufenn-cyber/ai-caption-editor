import SwiftUI

struct WaveformView: View {
    let samples: [Float]

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                guard !samples.isEmpty else { return }
                let centerY = size.height / 2
                let step = size.width / CGFloat(max(samples.count, 1))

                var path = Path()
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * step
                    let amplitude = CGFloat(sample) * (size.height * 0.48)
                    path.move(to: CGPoint(x: x, y: centerY - amplitude))
                    path.addLine(to: CGPoint(x: x, y: centerY + amplitude))
                }

                context.stroke(
                    path,
                    with: .color(Color.cyan.opacity(0.58)),
                    style: StrokeStyle(lineWidth: max(1, step * 0.75), lineCap: .round)
                )
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.52), Color.blue.opacity(0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
