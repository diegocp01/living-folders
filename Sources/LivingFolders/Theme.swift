import AppKit
import SwiftUI

/// Light frosted-glass theme, taken from the original living-folders mockup:
/// light style, ~50% window transparency, system font.
enum Theme {
    // Light tint at 40% opacity; the native material supplies the blur.
    static let glass = Color(red: 0.949, green: 0.969, blue: 0.984).opacity(0.4)
    static let glassStrong = Color.white.opacity(0.55)

    static let canvas = Color(red: 0.894, green: 0.914, blue: 0.929) // #e4e9ed
    static let ink = Color(red: 0.161, green: 0.169, blue: 0.180)     // #292b2e
    static let hairline = Color.black.opacity(0.08)
    static let hairlineStrong = Color.black.opacity(0.16)
    static let secondary = Color(red: 0.43, green: 0.455, blue: 0.475)
    static let tertiary = Color(red: 0.55, green: 0.58, blue: 0.60)
    static let accent = Color(red: 0.18, green: 0.55, blue: 0.78)
    static let jevLive = Color(red: 0.22, green: 0.57, blue: 0.41)   // #389269
    static let danger = Color(red: 0.72, green: 0.24, blue: 0.22)
    static let move = Animation.spring(duration: 0.3, bounce: 0.12)
    static let soft = Animation.easeOut(duration: 0.22)
}

/// Frosted window background with a light, translucent tint.
struct Backdrop: View {
    var body: some View {
        ZStack {
            FrostedView()
            Theme.glass
        }
        .ignoresSafeArea()
    }
}

struct FrostedView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// The same blue folder silhouette used in the original desktop mockup.
struct FolderGlyph: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: geo.size.width * 0.09)
                    .fill(Color(red: 0.51, green: 0.77, blue: 0.90))
                    .frame(width: geo.size.width * 0.46, height: geo.size.height * 0.35)
                RoundedRectangle(cornerRadius: geo.size.width * 0.10)
                    .fill(LinearGradient(colors: [Color(red: 0.51, green: 0.81, blue: 0.95), Color(red: 0.32, green: 0.67, blue: 0.85)], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) { Color.white.opacity(0.4).frame(height: 0.5).padding(.horizontal, 3) }
                    .padding(.top, geo.size.height * 0.17)
            }
        }
        .shadow(color: Theme.accent.opacity(0.18), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

struct FolderTab: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: 8))
            path.addQuadCurve(to: CGPoint(x: 8, y: 0), control: .zero)
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.closeSubpath()
        }
    }
}

struct Panel: ViewModifier {
    var radius: CGFloat = 22
    var fill = Color.white.opacity(0.5)
    var stroke = Theme.hairline

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 1))
    }
}

extension View {
    func panel(radius: CGFloat = 22, fill: Color = Color.white.opacity(0.5), stroke: Color = Theme.hairline) -> some View {
        modifier(Panel(radius: radius, fill: fill, stroke: stroke))
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? Color.white : Theme.ink.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(prominent ? Theme.ink : Color.white.opacity(configuration.isPressed ? 0.7 : 0.45)))
            .overlay(Capsule().strokeBorder(prominent ? .clear : Theme.hairlineStrong, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.soft, value: configuration.isPressed)
    }
}

struct ThinkingDots: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 5, height: 5)
                    .opacity(phase ? 1 : 0.25)
                    .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(Double(index) * 0.14), value: phase)
            }
        }
        .onAppear { phase = true }
    }
}
