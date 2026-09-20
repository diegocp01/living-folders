import AppKit
import SwiftUI
import LivingFoldersCore

/// "Check for updates" control. Lives top-left in the window chrome, under the
/// app title area. Checks the GitHub repo for new commits; when the user
/// confirms, it git-pulls and restarts the app.
struct UpdateButton: View {
    private enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available
        case updating
        case error(String)
    }

    @State private var phase: Phase = .idle
    @State private var revertTask: Task<Void, Never>?

    var body: some View {
        Button(action: tap) {
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
        .disabled(phase == .checking || phase == .updating)
    }

    // MARK: - State machine

    private func tap() {
        switch phase {
        case .idle, .upToDate, .error:
            startCheck()
        case .available:
            startUpdate()
        case .checking, .updating:
            break
        }
    }

    private func startCheck() {
        phase = .checking
        Task {
            let result = await Updater.check()
            await MainActor.run {
                switch result {
                case .upToDate:
                    phase = .upToDate
                    scheduleRevert()
                case .available:
                    phase = .available
                case .noSourceDir:
                    phase = .error("No source checkout found")
                    scheduleRevert()
                case .failed(let message):
                    phase = .error(message)
                    scheduleRevert()
                }
            }
        }
    }

    private func startUpdate() {
        phase = .updating
        Task {
            let ok = await Updater.pull()
            await MainActor.run {
                if ok {
                    relaunch()
                } else {
                    phase = .error("Pull failed")
                    scheduleRevert()
                }
            }
        }
    }

    private func scheduleRevert() {
        revertTask?.cancel()
        revertTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            phase = .idle
        }
    }

    /// Opens a fresh instance of this app, then quits the old one.
    private func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        let opener = Process()
        opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        opener.arguments = ["-n", bundleURL.path]
        try? opener.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Presentation

    @ViewBuilder
    private var icon: some View {
        switch phase {
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
        switch phase {
        case .idle: "Check for updates"
        case .checking: "Checking…"
        case .upToDate: "Up to date"
        case .available: "Update available — restart to apply"
        case .updating: "Updating…"
        case .error(let message): message
        }
    }

    private var foreground: Color {
        switch phase {
        case .error: Theme.danger
        default: Theme.secondary
        }
    }
}
