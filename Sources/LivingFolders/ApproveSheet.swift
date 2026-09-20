import SwiftUI
import LivingFoldersCore

struct ApproveSheet: View {
    @Bindable var model: WorkspaceModel
    let plan: MovePlan

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create “\(plan.destination.lastPathComponent)”")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(plan.items.count) \(plan.items.count == 1 ? "item" : "items") will move into a new folder inside \(plan.root.lastPathComponent). Nothing is deleted or overwritten.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.items) { item in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(item.name)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.ink.opacity(0.9))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if let confidence = model.memberships[item.id]?.confidence {
                                Text("\(Int((confidence * 100).rounded()))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Theme.tertiary)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 220)
            .panel(radius: 14)

            VStack(alignment: .leading, spacing: 6) {
                Text("SHELL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.tertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plan.commands, id: \.self) { command in
                            Text(command.display)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.ink.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    .padding(12)
                }
                .panel(radius: 12, fill: .black.opacity(0.35))
            }

            HStack {
                Spacer()
                Button("Cancel") { model.plan = nil }
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button {
                    Task { await model.approve() }
                } label: {
                    HStack(spacing: 8) {
                        if model.isMoving { ProgressView().controlSize(.small).tint(Theme.canvas) }
                        Text(model.isMoving ? "Moving…" : "Move \(plan.items.count)")
                    }
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(model.isMoving)
            }
        }
        .padding(26)
        .frame(width: 520)
        .background(Backdrop())
        .preferredColorScheme(.dark)
    }
}
