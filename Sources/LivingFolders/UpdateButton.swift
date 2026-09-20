import AppKit
import SwiftUI
import LivingFoldersCore

/// "Check for updates" pill. Lives top-left in the window chrome, under the
/// app title area. State comes from the shared UpdateController so the pill
/// and the app-menu item always agree.
struct UpdateButton: View {
    @Bindable var controller: UpdateController

    var body: some View {
        Button(action: { controller.userRequestedAction() }) {
            HStack(spacing: 6) {
                icon
                Text(label)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.glassStrong))
            .overlay(Capsule().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Check the GitHub repo for updates")
        .disabled(controller.phase == .checking || controller.phase == .updating)
    }

    // MARK: - Presentation

    @ViewBuilder
    private var icon: some View {
        switch controller.phase {
        case .checking, .updating:
            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
        case .upToDate:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.jevLive)
        case .available:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
        case .error:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(Theme.danger)
        case .idle:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 11))
        }
    }

    private var label: String {
        switch controller.phase {
        case .idle: "Check for updates"
        case .checking: "Checking…"
        case .upToDate: "Up to date"
        case .available: "Update available — restart to apply"
        case .updating: "Updating…"
        case .error(let message): message
        }
    }

    private var foreground: Color {
        switch controller.phase {
        case .error: Theme.danger
        default: Theme.secondary
        }
    }
}
