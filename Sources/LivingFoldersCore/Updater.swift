import Foundation

/// Self-update: compares this checkout against the GitHub repo and pulls when behind.
/// Uses only git — no API keys, no network beyond the public repo.
public enum Updater {
    public static let repoURL = "https://github.com/diegocp01/living-folders.git"
    public static let defaultBranch = "main"

    public enum CheckResult: Equatable {
        case upToDate
        case available(local: String, remote: String)
        case noSourceDir
        case failed(String)
    }

    /// Pure version comparison, kept separate so it stays unit-testable.
    public static func needsUpdate(local: String, remote: String) -> Bool {
        !local.isEmpty && !remote.isEmpty && local != remote
    }

    /// Walks up from the running .app bundle looking for the source checkout
    /// (build/LivingFolders.app -> repo root, which holds .git).
    public static func findSourceDir(from bundleURL: URL) -> URL? {
        var dir = bundleURL
        if dir.pathExtension == "app" { dir = dir.deletingLastPathComponent() }
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path) {
                return dir
            }
            let parent = dir.deletingLastPathComponent()
            if parent == dir { break }
            dir = parent
        }
        return nil
    }

    /// Full check: find checkout, read local HEAD, read remote HEAD, compare.
    /// `bundleURL` defaults to the running app; injectable for tests.
    public static func check(bundleURL: URL = Bundle.main.bundleURL) async -> CheckResult {
        await Task.detached(priority: .userInitiated) {
            guard let dir = findSourceDir(from: bundleURL) else { return .noSourceDir }
            guard let local = localHEAD(in: dir) else {
                return .failed("Could not read the local git revision.")
            }
            guard let remote = remoteHEAD() else {
                return .failed("Could not reach \(repoURL). Check your connection.")
            }
            return needsUpdate(local: local, remote: remote)
                ? .available(local: local, remote: remote)
                : .upToDate
        }.value
    }

    /// Fast-forward pulls the default branch. Returns true on success.
    public static func pull(bundleURL: URL = Bundle.main.bundleURL) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            guard let dir = findSourceDir(from: bundleURL) else { return false }
            let (_, status) = git(["pull", "--ff-only", "origin", defaultBranch], in: dir)
            return status == 0
        }.value
    }

    // MARK: - git plumbing

    static func localHEAD(in dir: URL) -> String? {
        let (out, status) = git(["rev-parse", "HEAD"], in: dir)
        return status == 0 && !out.isEmpty ? out : nil
    }

    static func remoteHEAD() -> String? {
        // ls-remote reads the remote ref without touching the local checkout.
        let (out, status) = git(["ls-remote", repoURL, "HEAD"], in: URL(fileURLWithPath: "/tmp"))
        guard status == 0 else { return nil }
        return out.split(separator: "\t").first.map(String.init)
    }

    @discardableResult
    static func git(_ args: [String], in dir: URL) -> (output: String, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return ("", -1)
        }
        process.waitUntilExit()
        let raw = outPipe.fileHandleForReading.readDataToEndOfFile()
        let output = (String(data: raw, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (output, process.terminationStatus)
    }
}
