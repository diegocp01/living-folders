import Foundation

/// Self-update: compares this checkout against the GitHub repo, and when the
/// user confirms, produces a *new* app bundle and reports what went wrong if it
/// cannot.
///
/// The important detail is that updating is not `git pull`. Pulling only moves
/// source; the running `.app` is unchanged until something rebuilds or
/// re-downloads it. So `update()` delegates to `build.sh`, which already knows
/// both routes: build from source when Xcode is present, download the prebuilt
/// release when it is not.
public enum Updater {
    public static let repoURL = "https://github.com/diegocp01/living-folders.git"
    public static let defaultBranch = "main"

    public enum CheckResult: Equatable {
        case upToDate
        case available(local: String, remote: String)
        case noSourceDir
        case failed(String)
    }

    public enum UpdateResult: Equatable {
        case updated
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

    /// Installs the newest version over the current bundle.
    ///
    /// With Xcode, the source has to be current before it can be compiled, so a
    /// failed `git pull` is fatal. Without Xcode the new app comes from the
    /// release asset, which does not depend on the checkout at all — so a messy
    /// working tree must not block the update. That asymmetry is deliberate.
    public static func update(bundleURL: URL = Bundle.main.bundleURL) async -> UpdateResult {
        await Task.detached(priority: .userInitiated) {
            guard let dir = findSourceDir(from: bundleURL) else {
                return .failed("Could not find the Living Folders checkout next to the app. Re-run ./build.sh --download --open from the repo.")
            }
            let script = dir.appendingPathComponent("build.sh")
            guard FileManager.default.fileExists(atPath: script.path) else {
                return .failed("build.sh is missing from \(dir.lastPathComponent), so the app cannot be rebuilt.")
            }

            if hasXcode() {
                let pull = run("/usr/bin/git", ["pull", "--ff-only", "origin", defaultBranch], in: dir)
                guard pull.status == 0 else {
                    return .failed(message(from: pull, fallback: "git pull failed."))
                }
                let build = run("/bin/bash", [script.path, "--from-source"], in: dir)
                guard build.status == 0 else {
                    return .failed(message(from: build, fallback: "Building from source failed."))
                }
            } else {
                let download = run("/bin/bash", [script.path, "--download"], in: dir)
                guard download.status == 0 else {
                    return .failed(message(from: download, fallback: "Downloading the new app failed."))
                }
            }
            return .updated
        }.value
    }

    /// Command Line Tools ship `swift` but not `xcodebuild`; that is the signal
    /// build.sh uses, and this mirrors it so both agree on the route taken.
    static func hasXcode() -> Bool {
        run("/usr/bin/xcrun", ["--find", "xcodebuild"], in: URL(fileURLWithPath: "/")).status == 0
    }

    /// Picks the line a human should read. Command failures put the useful part
    /// last on stderr, and git's first line is usually just "From <remote>".
    static func message(from result: CommandResult, fallback: String) -> String {
        let lines = (result.stderr + "\n" + result.stdout)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("From ") && !$0.hasPrefix("remote:") }
        guard let line = lines.last else { return fallback }
        return line.count > 160 ? String(line.prefix(159)) + "…" : line
    }

    // MARK: - process plumbing

    public struct CommandResult: Sendable {
        public let stdout: String
        public let stderr: String
        public let status: Int32
    }

    static func localHEAD(in dir: URL) -> String? {
        let result = run("/usr/bin/git", ["rev-parse", "HEAD"], in: dir)
        return result.status == 0 && !result.stdout.isEmpty ? result.stdout : nil
    }

    static func remoteHEAD() -> String? {
        // ls-remote reads the remote ref without touching the local checkout.
        let result = run("/usr/bin/git", ["ls-remote", repoURL, "HEAD"], in: URL(fileURLWithPath: "/tmp"))
        guard result.status == 0 else { return nil }
        return result.stdout.split(separator: "\t").first.map(String.init)
    }

    /// Runs a command and captures both streams.
    ///
    /// Both pipes are drained on background queues before `waitUntilExit`.
    /// Draining them in sequence deadlocks as soon as the other stream fills its
    /// buffer, which `build.sh` is perfectly capable of doing.
    @discardableResult
    static func run(_ tool: String, _ args: [String], in dir: URL) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.currentDirectoryURL = dir

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return CommandResult(stdout: "", stderr: error.localizedDescription, status: -1)
        }

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "updater.read", attributes: .concurrent)
        queue.async(group: group) { outData = outPipe.fileHandleForReading.readDataToEndOfFile() }
        queue.async(group: group) { errData = errPipe.fileHandleForReading.readDataToEndOfFile() }
        group.wait()
        process.waitUntilExit()

        func text(_ data: Data) -> String {
            (String(data: data, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return CommandResult(stdout: text(outData), stderr: text(errData), status: process.terminationStatus)
    }
}
