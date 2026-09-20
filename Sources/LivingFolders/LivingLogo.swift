import SwiftUI
import AppKit

/// Reports the mouse position inside its bounds (AppKit coordinates, origin bottom-left).
struct MouseTracker: NSViewRepresentable {
    @Binding var point: CGPoint?
    @Binding var area: CGSize

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onMove = { loc, size in
            point = loc
            area = size
        }
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {}

    final class TrackingView: NSView {
        var onMove: ((CGPoint?, CGSize) -> Void)?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
        }

        override func mouseMoved(with event: NSEvent) {
            onMove?(convert(event.locationInWindow, from: nil), bounds.size)
        }

        override func mouseExited(with event: NSEvent) {
            onMove?(nil, bounds.size)
        }
    }
}

/// The "Living Folders" wordmark, alive: it drifts gently on its own and
/// leans a few points toward the cursor. Keeps the light minimal mockup
/// style: system font, ink color, no chrome, no glow.
struct LivingLogo: View {
    /// Mouse position in the tracked area (AppKit coords), nil when unknown.
    var mouse: CGPoint?
    /// Size of the tracked area the mouse coordinates are relative to.
    var area: CGSize

    @State private var appeared = false
    @State private var pointer: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private let letters = Array("Living Folders")

    private var widths: [CGFloat] {
        let font = NSFont.systemFont(ofSize: 38, weight: .light)
        return letters.map { (String($0) as NSString).size(withAttributes: [.font: font]).width }
    }

    /// Parallax offset for a layer; `depth` 1.0 is the title, smaller values lag behind.
    private func parallax(depth: CGFloat) -> CGSize {
        guard !reduceMotion, scenePhase == .active, let mouse, area.width > 0, area.height > 0 else { return .zero }
        let nx = mouse.x / area.width - 0.5      // -0.5 ... 0.5
        let ny = mouse.y / area.height - 0.5     // AppKit y is up; SwiftUI offset y is down
        return CGSize(width: nx * 14 * depth, height: -ny * 10 * depth)
    }

    var body: some View {
        VStack(spacing: 14) {
            Group {
                if reduceMotion {
                    Text("Living Folders")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Theme.ink)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { timeline in
                        wordmark(time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Living Folders")
            Text("Open a folder. Name what you want.\nWatch it fill, then approve the move.")
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .offset(
                    x: parallax(depth: 0.5).width,
                    y: (appeared || reduceMotion ? 0 : 10) + parallax(depth: 0.5).height
                )
                .opacity(appeared || reduceMotion ? 1 : 0)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7), value: mouse)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pointer = nil }
        }
        .onAppear {
            appeared = true
        }
    }

    private func wordmark(time: TimeInterval) -> some View {
        let measured = widths
        return HStack(spacing: -0.5) {
            ForEach(letters.indices, id: \.self) { index in
                let center = measured.prefix(index).reduce(0, +) - CGFloat(index) * 0.5 + measured[index] / 2
                let distance = pointer.map { hypot($0.x - center, $0.y - 32) } ?? 180
                let influence = max(0, 1 - distance / 110)
                let phase = time * 0.8 - Double(index) * 0.48
                Text(String(letters[index]))
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Theme.ink)
                    .frame(width: measured[index])
                    .scaleEffect(1 + influence * 0.12)
                    .rotationEffect(.degrees(sin(phase) * 1.8 + Double(influence) * (Double(index % 3) - 1) * 5))
                    .offset(y: sin(phase) * 2.5 - Double(influence) * 9 + (appeared ? 0 : 14))
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.48, dampingFraction: 0.58), value: pointer)
                    .animation(.spring(response: 0.65, dampingFraction: 0.72).delay(Double(index) * 0.025), value: appeared)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location): pointer = location
            case .ended: pointer = nil
            }
        }
        .offset(parallax(depth: 1))
    }
}
