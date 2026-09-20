import SwiftUI
import LivingFoldersCore

@main
struct LivingFoldersApp: App {
    @State private var model = WorkspaceModel()

    var body: some Scene {
        WindowGroup("Living Folders") {
            ZStack {
                Backdrop()
                if model.root == nil {
                    WelcomeView(model: model).transition(.opacity)
                } else {
                    WorkspaceView(model: model).transition(.opacity)
                }
            }
            .animation(Theme.soft, value: model.root == nil)
            .frame(minWidth: 940, minHeight: 620)
            .preferredColorScheme(.light)
            .onAppear {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                // Frosted 50%-transparent window, like the original mockup.
                if let window = NSApp.windows.first {
                    window.isOpaque = false
                    window.backgroundColor = .clear
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") { model.chooseFolder() }.keyboardShortcut("o", modifiers: .command)
                Button("Rescan Folder") { model.rescan() }.keyboardShortcut("r", modifiers: .command).disabled(model.root == nil)
            }
        }

        Settings { SettingsView(model: model) }
    }
}

private struct SettingsView: View {
    @Bindable var model: WorkspaceModel
    @AppStorage("TYPESAFE_API_KEY") private var apiKey = ""
    @State private var keySource: JevClassifier.KeySource?

    private func refreshKeySource() {
        keySource = JevClassifier.resolveKeyWithSource()?.source
    }

    var body: some View {
        Form {
            Section("Jev") {
                SecureField("TYPESAFE_API_KEY", text: $apiKey)
                    .onSubmit { model.credentialsChanged(); refreshKeySource() }
                Button("Apply key") { model.credentialsChanged(); refreshKeySource() }
                if keySource == .dotEnv {
                    Text("Using TYPESAFE_API_KEY from .env in the repo folder — it takes priority over the key above.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if keySource == .environment {
                    Text("Using TYPESAFE_API_KEY from the environment — it takes priority over the key above.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("A key is required for gathering. Jev receives the folder prompt, filenames, types, sizes and dates—not file contents or full paths. Typing and folder changes can use API credits. A configured key is only shown as ready after a successful classification.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onAppear(perform: refreshKeySource)
    }
}
