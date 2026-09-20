import SwiftUI

struct PromptBar: View {
    @Bindable var model: WorkspaceModel
    @FocusState private var focused: Bool

    static let presets = ["Screenshots", "Photos from this week", "PDFs and documents", "Installers and archives", "Old stuff"]

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
                    .onChange(of: model.prompt) { previous, _ in model.promptChanged(from: previous) }
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
            .panel(radius: 27, fill: Color.white.opacity(0.06), stroke: focused ? Theme.hairlineStrong : Theme.hairline)
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
                ForEach(Self.presets, id: \.self) { preset in
                    Button(preset) { model.usePreset(preset) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(model.prompt == preset ? Theme.ink : Theme.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(model.prompt == preset ? 0.1 : 0.03)))
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                }
            }
            .padding(.horizontal, 6)
        }
        .onAppear { focused = true }
    }
}
