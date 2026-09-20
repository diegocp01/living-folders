import AppKit
import Observation
import LivingFoldersCore

enum ClassificationMode: String {
    case local, jev

    var label: String { self == .jev ? "Jev ready" : "On-device rules" }
}

@MainActor @Observable
final class WorkspaceModel {
    static let displayLimit = 120
    static let recentsKey = "recentFolders"

    var root: URL?
    var items: [FileItem] = []
    var prompt = ""
    var memberships: [String: Membership] = [:]
    var isThinking = false
    var status = "Name the folder. It fills as you type."
    var mode: ClassificationMode = JevClassifier.resolveKey() == nil ? .local : .jev
    var toast: (text: String, isError: Bool)?
    var plan: MovePlan?
    var isMoving = false
    var lastResult: MoveResult?
    var recents: [URL] = (UserDefaults.standard.stringArray(forKey: WorkspaceModel.recentsKey) ?? []).map { URL(fileURLWithPath: $0) }

    private var version = 0
    private var debounce: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var cache: [String: [Membership]] = [:]
    private let local = LocalClassifier()

    init() {
        // `open LivingFolders.app --args /path/to/folder` opens straight into that folder.
        if let path = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) {
            let url = URL(fileURLWithPath: path)
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { open(url) }
        }
    }

    var visibleItems: [FileItem] { Array(items.prefix(Self.displayLimit)) }
    var gathered: [FileItem] { items.filter { memberships[$0.id]?.belongs == true } }
    var scattered: [FileItem] { visibleItems.filter { memberships[$0.id]?.belongs != true } }
    var folderTitle: String { prompt.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled folder" : prompt.trimmingCharacters(in: .whitespaces) }
    var canApprove: Bool { !gathered.isEmpty && !isThinking && !isMoving && ShellMover.folderName(from: prompt) != nil }

    // MARK: Folder

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose the folder Living Folders should work inside."
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func open(_ url: URL) {
        root = url
        reset()
        rescan()
        recents.removeAll { $0.path == url.path }
        recents.insert(url, at: 0)
        recents = Array(recents.prefix(6))
        UserDefaults.standard.set(recents.map(\.path), forKey: Self.recentsKey)
    }

    func closeFolder() {
        root = nil
        items = []
        reset()
    }

    func rescan() {
        guard let root else { return }
        do {
            items = try FolderScanner.scan(root)
            cache.removeAll()
        } catch {
            items = []
            show("Could not read \(root.lastPathComponent): \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: Typing

    func promptChanged(from previous: String) {
        debounce?.cancel()
        version += 1
        let name = prompt.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if name.isEmpty {
            if memberships.isEmpty { isThinking = false } else { reset(keepPrompt: true) }
            return
        }
        if name.count < 3 {
            isThinking = false
            status = "Keep typing. The idea is still too short."
            return
        }
        isThinking = true
        status = "Updating folder…"
        let currentVersion = version
        // Space and paste dispatch immediately; unfinished words wait for a short idle gap.
        let immediate = prompt.hasSuffix(" ") || prompt.count - previous.count > 1
        debounce = Task { [weak self] in
            if !immediate { try? await Task.sleep(for: .milliseconds(90)) }
            guard !Task.isCancelled else { return }
            await self?.classify(name, version: currentVersion)
        }
    }

    func usePreset(_ text: String) {
        let previous = prompt
        prompt = text
        promptChanged(from: previous)
    }

    private func classify(_ name: String, version: Int) async {
        let started = DispatchTime.now()
        do {
            let result: [Membership]
            if let cached = cache[name] {
                result = cached
            } else if mode == .jev, let key = JevClassifier.resolveKey() {
                result = try await JevClassifier(apiKey: key).classify(folderName: name, items: items)
            } else {
                result = local.classify(folderName: name, items: items)
            }
            guard version == self.version else { return }
            cache[name] = result
            apply(result, elapsed: Int(Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000))
        } catch {
            guard version == self.version else { return }
            isThinking = false
            status = error.localizedDescription
            show(error.localizedDescription, isError: true)
        }
    }

    private func apply(_ result: [Membership], elapsed: Int) {
        let before = Set(memberships.values.filter(\.belongs).map(\.id))
        lastResult = nil
        memberships = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        let after = Set(result.filter(\.belongs).map(\.id))
        let joined = after.subtracting(before).count
        let left = before.subtracting(after).count
        isThinking = false
        status = after.isEmpty
            ? "Nothing matches yet. Try a file type, a topic, or a time."
            : "\(after.count) \(after.count == 1 ? "item belongs" : "items belong") here · \(elapsed) ms · keep typing to change it"
        show(before.isEmpty ? "\(after.count) gathered" : "\(joined) joined · \(left) returned")
    }

    func reset(keepPrompt: Bool = false) {
        debounce?.cancel()
        version += 1
        memberships = [:]
        plan = nil
        lastResult = nil
        isThinking = false
        if !keepPrompt { prompt = "" }
        status = "Name the folder. It fills as you type."
    }

    // MARK: Moving

    func prepareApproval() {
        guard let root, canApprove else { return }
        do {
            plan = try ShellMover.plan(root: root, prompt: prompt, items: gathered)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    func approve() async {
        guard let plan else { return }
        isMoving = true
        defer { isMoving = false }
        do {
            let result = try await ShellMover.execute(plan)
            lastResult = result
            self.plan = nil
            memberships = [:]
            prompt = ""
            rescan()
            status = "Moved \(result.moved.count) \(result.moved.count == 1 ? "item" : "items") into \(result.destination.lastPathComponent)."
            show("\(result.moved.count) moved · \(result.elapsedMilliseconds) ms")
        } catch {
            show(error.localizedDescription, isError: true)
            rescan()
        }
    }

    func revealDestination() {
        guard let url = lastResult?.destination else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: Toast

    func show(_ text: String, isError: Bool = false) {
        toastTask?.cancel()
        toast = (text, isError)
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(isError ? 4 : 2.2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
