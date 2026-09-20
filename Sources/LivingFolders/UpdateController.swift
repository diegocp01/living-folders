import AppKit
import Observation
import LivingFoldersCore

/// Update state machine behind the "Check for Updates…" item in the app menu.
/// Checks the GitHub repo for new commits; when the user confirms, it installs
/// the new version and restarts.
///
/// `phase` drives any inline chrome. `notice` drives the alert, which is the
/// only feedback a user gets when the update is run from the menu bar — the
/// menu item itself cannot show status.
@MainActor @Observable
final class UpdateController {
    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available
        case updating
        case error(String)
    }

    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        /// Offers "Install and Restart" rather than a plain dismiss.
        let isConfirmation: Bool
    }

    private(set) var phase: Phase = .idle
    var notice: Notice?
    private var revertTask: Task<Void, Never>?

    /// Same behavior as tapping the pill: idle/up-to-date/error starts a
    /// check, available starts the update.
    func userRequestedAction() {
        switch phase {
        case .idle, .upToDate, .error:
            startCheck()
        case .available:
            startUpdate()
        case .checking, .updating:
            break
        }
    }

    /// The alert's "Install and Restart" button.
    func confirmUpdate() {
        guard phase == .available else { return }
        startUpdate()
    }

    private func startCheck() {
        phase = .checking
        Task {
            let result = await Updater.check()
            await MainActor.run {
                switch result {
                case .upToDate:
                    phase = .upToDate
                    notice = Notice(title: "You're up to date",
                                    message: "Living Folders is running the newest version.",
                                    isConfirmation: false)
                    scheduleRevert()
                case .available:
                    phase = .available
                    notice = Notice(title: "A new version is available",
                                    message: "Living Folders will install it and restart.",
                                    isConfirmation: true)
                case .noSourceDir:
                    fail("Could not find the Living Folders checkout next to the app.")
                case .failed(let message):
                    fail(message)
                }
            }
        }
    }

    private func startUpdate() {
        phase = .updating
        Task {
            let result = await Updater.update()
            await MainActor.run {
                switch result {
                case .updated:
                    relaunch()
                case .failed(let message):
                    fail(message)
                }
            }
        }
    }

    private func fail(_ message: String) {
        phase = .error(message)
        notice = Notice(title: "Update failed", message: message, isConfirmation: false)
        scheduleRevert()
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
}
