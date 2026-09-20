import SwiftUI
import LivingFoldersCore

struct FileCard: View {
    static let size = CGSize(width: 92, height: 98)

    let item: FileItem
    let membership: Membership?
    let inside: Bool
    let scale: CGFloat

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            MockupFileIcon(item: item)
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
                .fill(Color.black.opacity(hovering ? 0.05 : 0))
        )
        .scaleEffect(scale * (hovering ? 1.04 : 1))
        .animation(Theme.soft, value: hovering)
        .onHover { hovering = $0 }
        .help("\(item.name)\n\(item.url.path)")
        .accessibilityLabel(item.name)
    }
}

/// App-only artwork derived from the file type; never reads or modifies file contents.
private struct MockupFileIcon: View {
    let item: FileItem

    private var ext: String { item.ext.lowercased() }
    private var isPhoto: Bool { ["jpg", "jpeg", "png", "heic", "gif", "webp", "tiff"].contains(ext) }
    private var label: String {
        if ext == "pkpass" { return "PASS" }
        return ext.isEmpty ? "FILE" : String(ext.prefix(5)).uppercased()
    }
    private var tint: Color {
        switch ext {
        case "pdf": return Color(red: 0.94, green: 0.32, blue: 0.34)
        case "key": return Color(red: 0.37, green: 0.50, blue: 0.89)
        case "doc", "docx", "msg": return Color(red: 0.30, green: 0.52, blue: 0.82)
        case "url", "webloc": return Color(red: 0.29, green: 0.65, blue: 0.66)
        case "epub": return Color(red: 0.54, green: 0.38, blue: 0.77)
        case "ipynb": return Color(red: 0.90, green: 0.55, blue: 0.18)
        case "xlsx", "xls", "csv", "pkpass": return Color(red: 0.25, green: 0.61, blue: 0.44)
        default: return isPhoto ? Color(red: 0.36, green: 0.60, blue: 0.39) : Color(red: 0.43, green: 0.49, blue: 0.54)
        }
    }

    var body: some View {
        Group {
            if item.isDirectory {
                FolderGlyph()
                    .frame(width: 46, height: 53)
            } else {
                ZStack(alignment: .bottom) {
                    if isPhoto {
                        LinearGradient(colors: [Color(red: 0.60, green: 0.83, blue: 0.93), Color(red: 0.97, green: 0.82, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Circle().fill(Color(red: 1, green: 0.96, blue: 0.78))
                            .frame(width: 9, height: 9).offset(x: -12, y: -35)
                        Landscape().fill(Color(red: 0.42, green: 0.65, blue: 0.54))
                        Landscape().fill(Color(red: 0.29, green: 0.51, blue: 0.44)).offset(x: 18, y: 8)
                    } else {
                        Color.white
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2).fill(tint.opacity(0.88)).frame(height: 5)
                            Spacer()
                            VStack(spacing: 4) {
                                ForEach(0..<3) { _ in Rectangle().fill(tint.opacity(0.28)).frame(height: 2) }
                            }
                            .padding(.horizontal, 1)
                        }
                        .padding(.horizontal, 6).padding(.top, 8).padding(.bottom, 11)
                    }
                    Text(label)
                        .font(.system(size: 6, weight: .heavy))
                        .tracking(0.3)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 2)
                        .background(tint, in: RoundedRectangle(cornerRadius: 2))
                }
                .frame(width: 46, height: 53)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
            }
        }
        .shadow(color: .black.opacity(0.17), radius: 4, y: 3)
        .accessibilityHidden(true)
    }
}

private struct Landscape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height * 0.78))
            path.addLine(to: CGPoint(x: rect.width * 0.48, y: rect.height * 0.48))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.48))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}
