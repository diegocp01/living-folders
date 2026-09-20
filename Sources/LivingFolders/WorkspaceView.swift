import SwiftUI
import LivingFoldersCore

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)
            CardField(model: model)
                .padding(.horizontal, 22)
                .padding(.top, 8)
            PromptBar(model: model)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 20)
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
                Button("Change…") { model.chooseFolder() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            Text("\(model.items.count) items")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.tertiary)
            HStack(spacing: 6) {
                Circle().fill(model.mode == .jev ? Theme.accent : Theme.ink.opacity(0.7)).frame(width: 6, height: 6)
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

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let gap: CGFloat = 20
            let folderWidth = max(280, width * 0.36)
            let desktopRect = CGRect(x: 0, y: 0, width: width - folderWidth - gap, height: height)
            let folderRect = CGRect(x: width - folderWidth, y: 0, width: folderWidth, height: height)
            let scattered = model.scattered
            let gathered = model.gathered
            let desktopLayout = Layout.grid(count: scattered.count, in: desktopRect.insetBy(dx: 10, dy: 10))
            let folderLayout = Layout.grid(count: gathered.count, in: CGRect(x: folderRect.minX + 14, y: folderRect.minY + 78, width: folderRect.width - 28, height: folderRect.height - 96))

            ZStack(alignment: .topLeading) {
                DesktopZone(isEmpty: scattered.isEmpty && !model.items.isEmpty, hasItems: !model.items.isEmpty)
                    .frame(width: desktopRect.width, height: desktopRect.height)
                    .offset(x: desktopRect.minX, y: desktopRect.minY)

                FolderZone(model: model, count: gathered.count)
                    .frame(width: folderRect.width, height: folderRect.height)
                    .offset(x: folderRect.minX, y: folderRect.minY)

                ForEach(Array(scattered.enumerated()), id: \.element.id) { index, item in
                    card(item, at: desktopLayout.points[index], scale: desktopLayout.scale, inside: false)
                }
                ForEach(Array(gathered.enumerated()), id: \.element.id) { index, item in
                    card(item, at: folderLayout.points[index], scale: folderLayout.scale, inside: true)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
    }

    private func card(_ item: FileItem, at point: CGPoint, scale: CGFloat, inside: Bool) -> some View {
        FileCard(item: item, membership: model.memberships[item.id], inside: inside, scale: scale)
            .position(point)
            .animation(Theme.move, value: point)
            .animation(Theme.move, value: scale)
            .zIndex(inside ? 2 : 1)
    }
}

enum Layout {
    struct Result { var points: [CGPoint]; var scale: CGFloat }

    static func grid(count: Int, in area: CGRect) -> Result {
        guard count > 0, area.width > 0, area.height > 0 else { return Result(points: [], scale: 1) }
        let base = FileCard.size
        let fit = sqrt((area.width * area.height) / (CGFloat(count) * base.width * base.height))
        let scale = min(1, max(0.62, fit * 0.98))
        let cellW = base.width * scale
        let cellH = base.height * scale
        let columns = max(1, Int(area.width / cellW))
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let stepX = columns == 1 ? 0 : min(cellW + 6, (area.width - cellW) / CGFloat(columns - 1))
        let stepY = rows == 1 ? 0 : min(cellH + 4, max(cellH * 0.86, (area.height - cellH) / CGFloat(rows - 1)))
        let points = (0..<count).map { index in
            CGPoint(
                x: area.minX + cellW / 2 + CGFloat(index % columns) * stepX,
                y: area.minY + cellH / 2 + CGFloat(index / columns) * stepY
            )
        }
        return Result(points: points, scale: scale)
    }
}

private struct DesktopZone: View {
    let isEmpty: Bool
    let hasItems: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.012))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 1))
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
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.folderTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(count == 0 ? "Waiting for a name" : "\(count) \(count == 1 ? "item" : "items") · will be created inside \(model.root?.lastPathComponent ?? "")")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if model.isThinking { ThinkingDots() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            Spacer()
            if count == 0 {
                Text("Files gather here as you type.\nApprove to create the folder for real.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
            Spacer()
        }
        .panel(radius: 26, fill: Color.white.opacity(model.isThinking ? 0.055 : 0.04), stroke: model.isThinking ? Theme.accent.opacity(0.35) : Theme.hairlineStrong)
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
