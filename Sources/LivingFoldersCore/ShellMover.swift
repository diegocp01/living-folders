import Foundation

/// One shell invocation, shown to the user verbatim before it runs.
public struct ShellCommand: Hashable, Sendable {
    public let executable: String
    public let arguments: [String]

    public var display: String {
        ([executable] + arguments).map(Self.quote).joined(separator: " ")
    }

    static func quote(_ word: String) -> String {
        if word.isEmpty { return "''" }
        let safe = word.allSatisfy { $0.isLetter || $0.isNumber || "/-_.=+:@%".contains($0) }
        return safe ? word : "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public struct MovePlan: Sendable {
    public let root: URL
    public let destination: URL
    public let items: [FileItem]
    public let commands: [ShellCommand]

    public var isEmpty: Bool { items.isEmpty }
}

public struct MoveResult: Sendable {
    public let moved: [FileItem]
    public let destination: URL
    public let elapsedMilliseconds: Int
    public let log: [String]
}

public enum MoveError: LocalizedError {
    case invalidName, nothingToMove, commandFailed(ShellCommand, Int32, String)

    public var errorDescription: String? {
        switch self {
        case .invalidName: return "That name cannot be used as a folder name."
        case .nothingToMove: return "There is nothing to move."
        case .commandFailed(let command, let status, let stderr):
            return "`\(command.executable.split(separator: "/").last ?? "command")` exited with \(status). \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

/// Builds and runs the `/bin/mkdir` + `/bin/mv` commands that materialise a living folder.
public enum ShellMover {
    public static let mkdir = "/bin/mkdir"
    public static let mv = "/bin/mv"

    /// Turns a free-form folder name into a safe single path component.
    public static func folderName(from prompt: String) -> String? {
        var name = prompt
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = name.first, ".- ".contains(first) { name.removeFirst() }
        name = name.trimmingCharacters(in: .whitespaces)
        if name.count > 120 { name = String(name.prefix(120)).trimmingCharacters(in: .whitespaces) }
        return name.isEmpty ? nil : name
    }

    public static func plan(root: URL, prompt: String, items: [FileItem]) throws -> MovePlan {
        guard let name = folderName(from: prompt) else { throw MoveError.invalidName }
        let destination = root.appendingPathComponent(name, isDirectory: true)
        // Never move the destination into itself.
        let movable = items.filter { $0.url.standardizedFileURL != destination.standardizedFileURL }
        guard !movable.isEmpty else { throw MoveError.nothingToMove }
        var commands = [ShellCommand(executable: mkdir, arguments: ["-p", destination.path])]
        // -n: never overwrite something that already lives in the destination.
        commands.append(ShellCommand(executable: mv, arguments: ["-n"] + movable.map(\.url.path) + [destination.path]))
        return MovePlan(root: root, destination: destination, items: movable, commands: commands)
    }

    public static func execute(_ plan: MovePlan) async throws -> MoveResult {
        let started = DispatchTime.now()
        var log: [String] = []
        for command in plan.commands {
            log.append("$ " + command.display)
            let (status, output) = try await run(command)
            if !output.isEmpty { log.append(output) }
            guard status == 0 else { throw MoveError.commandFailed(command, status, output) }
        }
        let moved = plan.items.filter { FileManager.default.fileExists(atPath: plan.destination.appendingPathComponent($0.name).path) }
        let elapsed = Int(Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000)
        return MoveResult(moved: moved, destination: plan.destination, elapsedMilliseconds: elapsed, log: log)
    }

    static func run(_ command: ShellCommand) async throws -> (Int32, String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command.executable)
            process.arguments = command.arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (process.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
