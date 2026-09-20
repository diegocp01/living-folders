import SwiftUI

/// A small, deterministic network on each edge; the center stays quiet for onboarding.
struct WelcomeConstellation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if reduceMotion {
                field(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24, paused: scenePhase != .active)) { timeline in
                    field(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func field(time: TimeInterval) -> some View {
        Canvas { context, size in
            for side in 0..<2 {
                let points = positions(size: size, side: side, time: time)
                for index in points.indices {
                    let point = points[index]
                    for next in (index + 1)..<points.count {
                        let other = points[next]
                        let distance = hypot(point.x - other.x, point.y - other.y)
                        if distance < 115 {
                            var line = Path()
                            line.move(to: point)
                            line.addLine(to: other)
                            let opacity = 0.12 * (1 - Double(distance) / 115)
                            context.stroke(line, with: .color(Theme.accent.opacity(opacity)), lineWidth: 0.7)
                        }
                    }
                    let radius: CGFloat = index.isMultiple(of: 4) ? 2.2 : 1.5
                    let dot = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(Theme.accent.opacity(0.20)))
                }
            }
        }
    }

    private func positions(size: CGSize, side: Int, time: TimeInterval) -> [CGPoint] {
        let width = Double(size.width)
        let band = min(220.0, width * 0.22)
        let span = max(0.0, Double(size.height) - 150)
        return (0..<16).map { index in
            let phase = Double(index) * 2.39996 + Double(side) * 1.7
            let fraction = Double((index * 7) % 17) / 17.0
            let driftX = sin(time * 0.035 + phase) * 9
            let driftY = cos(time * 0.027 + phase) * 12
            let x = 22 + fraction * max(0, band - 44) + driftX
            let y = 75 + Double(index) / 15 * span + driftY
            return CGPoint(x: side == 0 ? x : width - x, y: y)
        }
    }
}
