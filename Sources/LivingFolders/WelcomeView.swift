import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @Bindable var model: WorkspaceModel
    @State private var dropping = false
    @State private var mouse: CGPoint?
    @State private var mouseArea: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LivingLogo(mouse: mouse, area: mouseArea)
            Button("Open Folder…") { model.chooseFolder() }
                .buttonStyle(PillButtonStyle(prominent: true))
                .keyboardShortcut("o", modifiers: .command)
                .padding(.top, 30)
            Text("or drop a folder anywhere")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.tertiary)
                .padding(.top, 12)

            if !model.recents.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECENT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.tertiary)
                        .padding(.bottom, 8)
                    ForEach(model.recents, id: \.path) { url in
                        Button { model.open(url) } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                Text(url.lastPathComponent)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.ink.opacity(0.9))
                                Text(url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Theme.hairline)
                    }
                }
                .frame(width: 420)
                .padding(.top, 48)
            }
            Spacer()
            Text("Jev classifies file metadata · file contents stay on your Mac · moves require your approval")
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MouseTracker(point: $mouse, area: $mouseArea))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.accent.opacity(dropping ? 0.6 : 0), lineWidth: 1.5)
                .padding(16)
                .animation(Theme.soft, value: dropping)
        )
        .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return }
                Task { @MainActor in model.open(url) }
            }
            return true
        }
    }
}
