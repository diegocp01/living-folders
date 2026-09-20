import SwiftUI

enum Theme {
    static let canvas = Color(red: 0.035, green: 0.037, blue: 0.047)
    static let ink = Color.white
    static let hairline = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.16)
    static let secondary = Color.white.opacity(0.52)
    static let tertiary = Color.white.opacity(0.3)
    static let accent = Color(red: 0.62, green: 0.82, blue: 1.0)
    static let danger = Color(red: 1.0, green: 0.45, blue: 0.42)
    static let move = Animation.spring(duration: 0.3, bounce: 0.12)
    static let soft = Animation.easeOut(duration: 0.22)
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            Theme.canvas
            RadialGradient(colors: [Theme.accent.opacity(0.11), .clear], center: .init(x: 0.82, y: 0.08), startRadius: 0, endRadius: 620)
            RadialGradient(colors: [Color(red: 0.55, green: 0.5, blue: 0.9).opacity(0.07), .clear], center: .init(x: 0.1, y: 0.95), startRadius: 0, endRadius: 560)
        }
        .ignoresSafeArea()
    }
}

struct Panel: ViewModifier {
    var radius: CGFloat = 22
    var fill = Color.white.opacity(0.035)
    var stroke = Theme.hairline

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 1))
    }
}

extension View {
    func panel(radius: CGFloat = 22, fill: Color = Color.white.opacity(0.035), stroke: Color = Theme.hairline) -> some View {
        modifier(Panel(radius: radius, fill: fill, stroke: stroke))
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? Theme.canvas : Theme.ink.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(prominent ? Theme.ink : Color.white.opacity(configuration.isPressed ? 0.14 : 0.08)))
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
