import SwiftUI
import LivingFoldersCore

@main
struct LivingFoldersApp: App {
    @State private var model = WorkspaceModel()

    var body: some Scene {
        WindowGroup("Living Folders") {
            ZStack {
                Backdrop()
                if !model.hasAPIKey {
                    OnboardingView(model: model).transition(.opacity)
                } else if model.root == nil {
                    WelcomeView(model: model).transition(.opacity)
                } else {
                    WorkspaceView(model: model).transition(.opacity)
                }
            }
            .animation(Theme.soft, value: model.hasAPIKey)
            .animation(Theme.soft, value: model.root == nil)
            .frame(minWidth: 940, minHeight: 620)
            .preferredColorScheme(.light)
            .alert(
                model.updateController.notice?.title ?? "",
                isPresented: Binding(
                    get: { model.updateController.notice != nil },
                    set: { if !$0 { model.updateController.notice = nil } }
                ),
                presenting: model.updateController.notice
            ) { notice in
                if notice.isConfirmation {
                    Button("Install and Restart") { model.updateController.confirmUpdate() }
                    Button("Later", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: { notice in
                Text(notice.message)
            }
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
                Button("Open Folder…") { model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(!model.hasAPIKey)
                Button("Rescan Folder") { model.rescan() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.root == nil || !model.hasAPIKey)
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { model.updateController.userRequestedAction() }
            }
        }

        Settings { SettingsView(model: model) }
    }
}

private struct SettingsView: View {
    @Bindable var model: WorkspaceModel
    @State private var draftKey = ""
    @State private var keySource: JevClassifier.KeySource?
    @State private var statusText: String?
    @State private var statusIsError = false

    private func refreshKeySource() {
        keySource = JevClassifier.resolveKeyWithSource()?.source
    }

    private func apply() {
        do {
            try KeychainCredentials.save(draftKey)
            draftKey = ""
            model.credentialsChanged()
            refreshKeySource()
            statusIsError = false
            statusText = model.hasAPIKey ? "Key saved to Keychain." : "Key cleared."
        } catch {
            statusIsError = true
            statusText = error.localizedDescription
        }
    }

    var body: some View {
        Form {
            Section("Jev") {
                SecureField("TYPESAFE_API_KEY", text: $draftKey)
                    .onSubmit { apply() }
                Button("Apply key") { apply() }
                if keySource == .dotEnv {
                    Text("Using TYPESAFE_API_KEY from .env in the repo folder — it takes priority over Keychain.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if keySource == .environment {
                    Text("Using TYPESAFE_API_KEY from the environment — it takes priority over Keychain.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if keySource == .stored {
                    Text("A key is saved in your macOS Keychain. Paste a new value and Apply to replace it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No key yet. Paste your TypeSafe key and Apply — gathering stays off until then.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let statusText {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(statusIsError ? Theme.danger : Theme.jevLive)
                }
                Link("Get a key at typesafe.ai", destination: URL(string: "https://typesafe.ai")!)
                Text("Pricing: $0.042 / MTok input · output free")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
