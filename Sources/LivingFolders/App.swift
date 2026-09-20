import SwiftUI

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
            .preferredColorScheme(.dark)
            .onAppear { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
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

    var body: some View {
        Form {
            Section("Jev (optional)") {
                SecureField("TYPESAFE_API_KEY", text: $apiKey)
                    .onChange(of: apiKey) { _, value in model.mode = value.isEmpty ? .local : .jev }
                Text("Without a key, classification runs on-device with filename, type, and date rules. With a key, each folder name is sent to Jev together with the names of the files in the open folder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
    }
}
