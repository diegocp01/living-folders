import SwiftUI
import LivingFoldersCore

struct FileCard: View {
    static let size = CGSize(width: 92, height: 98)

    let item: FileItem
    let membership: Membership?
    let inside: Bool
    let scale: CGFloat

    @State private var hovering = false

    private var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: item.url.path)
        image.size = NSSize(width: 44, height: 44)
        return image
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 5)
                .overlay(alignment: .bottomTrailing) {
                    if let membership, inside {
                        Text("\(Int((membership.confidence * 100).rounded()))")
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.canvas)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Theme.accent))
                            .offset(x: 6, y: 4)
                    }
                }
            Text(item.name)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(inside ? 0.95 : 0.72))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(width: Self.size.width - 8)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(hovering ? 0.07 : 0))
        )
        .scaleEffect(scale * (hovering ? 1.04 : 1))
        .animation(Theme.soft, value: hovering)
        .onHover { hovering = $0 }
        .help("\(item.name)\n\(item.url.path)")
        .accessibilityLabel(item.name)
    }
}
