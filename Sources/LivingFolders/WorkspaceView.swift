import SwiftUI
import LivingFoldersCore

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model).disabled(model.isMoving)
            PromptBar(model: model)
                .frame(maxWidth: 820)
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            Divider().overlay(Color.white.opacity(0.3))
            CardField(model: model)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            HStack {
                Text("\(model.items.count) files · \(model.gathered.count) gathered")
                Spacer()
                Text("Preview first · Move only after approval")
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
        }
        .overlay(alignment: .top) { ToastView(toast: model.toast).padding(.top, 18) }
        .sheet(isPresented: Binding(get: { model.plan != nil }, set: { if !$0 { model.plan = nil } })) {
            if let plan = model.plan { ApproveSheet(model: model, plan: plan) }
        }
    }
}

private struct TopBar: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        HStack(spacing: 14) {
            Spacer().frame(width: 62) // room for traffic lights
            if let root = model.root {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                    Text(root.deletingLastPathComponent().lastPathComponent)
                        .foregroundStyle(Theme.tertiary)
                    Text("/").foregroundStyle(Theme.tertiary.opacity(0.6))
                    Text(root.lastPathComponent).foregroundStyle(Theme.ink.opacity(0.9))
                }
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                Menu {
                    Button("Open folder…") { model.chooseFolder() }
                    Button("Create folder…") { model.chooseFolder(creating: true) }
                    Divider()
                    Button("Rescan folder") { model.rescan() }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Folder options")
            }
            Spacer()
            Text("\(model.items.count) items")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.tertiary)
            HStack(spacing: 6) {
                Circle().fill(model.mode == .jev ? Theme.jevLive : Theme.tertiary).frame(width: 6, height: 6)
                Text(model.mode.label)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            Button { model.closeFolder() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Close folder")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .frame(height: 50)
    }
}

/// Both zones and every card share one coordinate space so cards fly between them.
private struct CardField: View {
    @Bindable var model: WorkspaceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let gap: CGFloat = 20
            let folderWidth = max(280, width * 0.36)
            let desktopWidth = width - folderWidth - gap
            let scattered = model.scattered
            let gathered = model.gathered
            let height = max(geo.size.height, Layout.height(count: scattered.count, width: desktopWidth - 20) + 40,
                             Layout.height(count: gathered.count, width: folderWidth - 28) + 96)
            let desktopRect = CGRect(x: 0, y: 0, width: desktopWidth, height: height)
            let folderRect = CGRect(x: width - folderWidth, y: 0, width: folderWidth, height: height)
            let desktopLayout = Layout.grid(count: scattered.count, in: CGRect(x: 10, y: 30, width: desktopWidth - 20, height: height - 40))
            let folderLayout = Layout.grid(count: gathered.count, in: CGRect(x: folderRect.minX + 14, y: 78, width: folderWidth - 28, height: height - 96))
            let positions = Dictionary(uniqueKeysWithValues:
                zip(scattered, desktopLayout.points).map { ($0.id, $1) } + zip(gathered, folderLayout.points).map { ($0.id, $1) })

            ScrollView {
                ZStack(alignment: .topLeading) {
                    DesktopZone(isEmpty: scattered.isEmpty && !model.items.isEmpty, hasItems: !model.items.isEmpty)
                        .frame(width: desktopRect.width, height: height)
                    HStack {
                        Text("All files")
                        Spacer()
                        Text("\(scattered.count) scattered")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: desktopWidth - 20)
                    .offset(x: 10)
                    FolderZone(model: model, count: gathered.count)
                        .frame(width: folderWidth, height: height)
                        .offset(x: folderRect.minX)

                    ForEach(model.items) { item in
                        if let point = positions[item.id] {
                            card(item, at: point, scale: 1, inside: model.memberships[item.id]?.belongs == true)
                        }
                    }
                }
                .frame(width: width, height: height, alignment: .topLeading)
            }
        }
    }

    private func card(_ item: FileItem, at point: CGPoint, scale: CGFloat, inside: Bool) -> some View {
        FileCard(item: item, membership: model.memberships[item.id], inside: inside, scale: scale)
            .position(point)
            .animation(reduceMotion ? nil : Theme.move, value: point)
            .animation(reduceMotion ? nil : Theme.move, value: scale)
            .zIndex(inside ? 2 : 1)
    }
}

enum Layout {
    struct Result { var points: [CGPoint]; var scale: CGFloat }

    static func height(count: Int, width: CGFloat) -> CGFloat {
        let columns = max(1, Int(width / (FileCard.size.width + 6)))
        return CGFloat((count + columns - 1) / columns) * (FileCard.size.height + 4)
    }

    static func grid(count: Int, in area: CGRect) -> Result {
        guard count > 0, area.width > 0, area.height > 0 else { return Result(points: [], scale: 1) }
        let cell = FileCard.size
        let columns = max(1, Int(area.width / (cell.width + 6)))
        let points = (0..<count).map { index in
            CGPoint(
                x: area.minX + cell.width / 2 + CGFloat(index % columns) * (cell.width + 6),
                y: area.minY + cell.height / 2 + CGFloat(index / columns) * (cell.height + 4)
            )
        }
        return Result(points: points, scale: 1)
    }
}

private struct DesktopZone: View {
    let isEmpty: Bool
    let hasItems: Bool

    var body: some View {
        ZStack {
            Color.clear
            if !hasItems {
                Text("This folder is empty.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.tertiary)
            } else if isEmpty {
                Text("Everything belongs in the folder.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }
}

private struct FolderZone: View {
    @Bindable var model: WorkspaceModel
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                FolderGlyph().frame(width: 23, height: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.folderTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(count == 0 ? "Waiting for a name" : "\(count) matches")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if model.isThinking { ThinkingDots() }
            }
            .padding(.horizontal, 20)
            .frame(height: 60)
            Divider().overlay(Color.white.opacity(0.3))
            Spacer()
            if count == 0 {
                VStack(spacing: 18) {
                    FolderGlyph().frame(width: 52, height: 44).opacity(0.65)
                    Text("A little room for your next idea.")
                    Text("Start with a name above.")
                }
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
            Spacer()
        }
        .panel(radius: 14, fill: Color.white.opacity(model.isThinking ? 0.25 : 0.16), stroke: Color.white.opacity(0.65))
        .padding(.top, 16)
        .background(alignment: .topLeading) {
            FolderTab().fill(Color.white.opacity(0.3)).frame(width: 110, height: 24)
        }
        .shadow(color: Theme.accent.opacity(model.isThinking ? 0.12 : 0), radius: 30)
        .animation(Theme.soft, value: model.isThinking)
        .animation(Theme.soft, value: count == 0)
    }
}

private struct ToastView: View {
    let toast: (text: String, isError: Bool)?

    var body: some View {
        ZStack {
            if let toast {
                Text(toast.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(toast.isError ? Theme.danger : Theme.ink.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.canvas.opacity(0.9)))
                    .overlay(Capsule().strokeBorder(toast.isError ? Theme.danger.opacity(0.4) : Theme.hairlineStrong, lineWidth: 1))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.text)
            }
        }
        .animation(Theme.soft, value: toast?.text)
    }
}
