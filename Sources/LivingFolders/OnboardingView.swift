import SwiftUI
import LivingFoldersCore

/// First-run gate: the app cannot open folders or gather until a Jev key is saved.
struct OnboardingView: View {
    @Bindable var model: WorkspaceModel
    @State private var draftKey = ""
    @State private var errorText: String?
    @State private var savedConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LivingLogo(mouse: nil, area: .zero)
                .frame(width: 120, height: 120)
                .padding(.bottom, 18)
            Text("Add your Jev API key")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Living Folders needs your own TypeSafe key before it can classify files. The key stays in your macOS Keychain — never in the app bundle or logs.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .padding(.top, 10)

            SecureField("Paste TYPESAFE_API_KEY", text: $draftKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)
                .padding(.top, 22)
                .onSubmit { apply() }

            Button("Save key") { apply() }
                .buttonStyle(PillButtonStyle(prominent: true))
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.top, 14)

            if savedConfirm {
                Text("Key saved to Keychain.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.jevLive)
                    .padding(.top, 10)
            }
            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
                    .padding(.top, 8)
            }

            Link("Get a key at typesafe.ai", destination: URL(string: "https://typesafe.ai")!)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)
                .padding(.top, 22)
            Text("Pricing: $0.042 / MTok input · output free")
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
                .padding(.top, 6)

            Spacer()
            Text("No gathering without a key · file contents stay on your Mac")
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func apply() {
        let trimmed = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainCredentials.save(trimmed)
            draftKey = ""
            errorText = nil
            savedConfirm = true
            model.credentialsChanged()
        } catch {
            savedConfirm = false
            errorText = error.localizedDescription
        }
    }
}
