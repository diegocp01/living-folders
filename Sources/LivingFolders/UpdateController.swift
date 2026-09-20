import AppKit
import Observation
import LivingFoldersCore

/// Shared update state machine. Drives both the "Check for updates" pill in
/// the window chrome and the "Check for Updates…" item in the app menu, so
/// they always show the same status. Checks the GitHub repo for new commits;
/// when the user confirms, it git-pulls and restarts the app.
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

    private(set) var phase: Phase = .idle
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
}
