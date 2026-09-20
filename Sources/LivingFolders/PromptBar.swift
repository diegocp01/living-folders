import SwiftUI

struct PromptBar: View {
    @Bindable var model: WorkspaceModel
    @FocusState private var focused: Bool

    static let presets = [
        (label: "Japan trip", prompt: "Stuff for my Japan trip"),
        (label: "At the airport", prompt: "Stuff I need at the airport"),
        (label: "A different person", prompt: "Things I downloaded to become a different person"),
        (label: "Just Python", prompt: "Fine. Just the Python tutorials."),
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(model.isThinking ? Theme.accent : Theme.tertiary)
                    .animation(Theme.soft, value: model.isThinking)
                TextField("Name a folder in plain language…", text: $model.prompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .focused($focused)
                    .onSubmit { if model.canApprove { model.prepareApproval() } }
                if !model.prompt.isEmpty {
                    Button { model.reset() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
                if model.canApprove {
                    Button { model.prepareApproval() } label: {
                        HStack(spacing: 6) {
                            Text("Move \(model.gathered.count)")
                            Image(systemName: "return")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .keyboardShortcut(.return, modifiers: .command)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(height: 54)
            .panel(radius: 27, fill: Color.white.opacity(0.7), stroke: focused ? Theme.accent.opacity(0.5) : Theme.hairlineStrong)
            .animation(Theme.soft, value: model.canApprove)
            .animation(Theme.soft, value: model.prompt.isEmpty)

            HStack(spacing: 8) {
                Text(model.status)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(Theme.soft, value: model.status)
                if model.lastResult != nil {
                    Button("Reveal in Finder") { model.revealDestination() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Text("Try").font(.system(size: 11.5)).foregroundStyle(Theme.tertiary)
                ForEach(Self.presets, id: \.label) { preset in
                    Button(preset.label) { model.usePreset(preset.prompt) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(model.prompt == preset.prompt ? Theme.ink : Theme.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(model.prompt == preset.prompt ? 0.75 : 0.4)))
                        .overlay(Capsule().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                }
            }
            .padding(.horizontal, 6)
        }
        .disabled(model.isMoving)
        .onAppear { focused = true }
    }
}
