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
        var onMove: ((CGPoint, CGSize) -> Void)?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
        }

        override func mouseMoved(with event: NSEvent) {
            onMove?(convert(event.locationInWindow, from: nil), bounds.size)
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
    @State private var floating = false

    /// Parallax offset for a layer; `depth` 1.0 is the title, smaller values lag behind.
    private func parallax(depth: CGFloat) -> CGSize {
        guard let mouse, area.width > 0, area.height > 0 else { return .zero }
        let nx = mouse.x / area.width - 0.5      // -0.5 ... 0.5
        let ny = mouse.y / area.height - 0.5     // AppKit y is up; SwiftUI offset y is down
        return CGSize(width: nx * 14 * depth, height: -ny * 10 * depth)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Living Folders")
                .font(.system(size: 38, weight: .light))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)
                .offset(
                    x: parallax(depth: 1).width,
                    y: (floating ? -3.5 : 3.5) + (appeared ? 0 : 10) + parallax(depth: 1).height
                )
                .opacity(appeared ? 1 : 0)
            Text("Open a folder. Name what you want.\nWatch it fill, then approve the move.")
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .offset(
                    x: parallax(depth: 0.5).width,
                    y: (appeared ? 0 : 10) + parallax(depth: 0.5).height
                )
                .opacity(appeared ? 1 : 0)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: mouse)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}
