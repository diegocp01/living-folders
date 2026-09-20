import AppKit
import Observation
import LivingFoldersCore

enum ClassificationMode: String {
    case missingKey, configured, jev, unavailable

    var label: String {
        switch self {
        case .missingKey: return "Jev key required"
        case .configured: return "Jev configured"
        case .jev: return "Jev ready"
        case .unavailable: return "Jev unavailable"
        }
    }
}

@MainActor @Observable
final class WorkspaceModel {
    static let recentsKey = "recentFolders"

    private(set) var root: URL?
    private(set) var items: [FileItem] = []
    var prompt = "" { didSet { if prompt != oldValue { promptChanged(from: oldValue) } } }
    let gathering: GatheringEngine
    var memberships: [String: Membership] { gathering.memberships }
    var isThinking: Bool { isScanning || gathering.isThinking }
    var status: String {
        if isMoving { return "Moving approved items…" }
        if let scanError { return scanError }
        if isScanning { return "Reading folder…" }
        if let result = lastResult {
            return "Moved \(result.moved.count) items into \(result.destination.lastPathComponent)."
        }
        return gathering.status
    }
    var mode: ClassificationMode {
        if apiKey == nil { return .missingKey }
        if gathering.error != nil { return .unavailable }
        return gathering.hasSuccessfulResponse ? .jev : .configured
    }
    var toast: (text: String, isError: Bool)?
    var plan: MovePlan?
    private(set) var isMoving = false
    private(set) var isScanning = false
    private(set) var lastResult: MoveResult?
    var recents: [URL]

    private var scanVersion = 0
    private var folderVersion = 0
    private var planGeneration = -1
    private var scanTask: Task<Void, Never>?
    private var watcher: FolderWatcher?
    private var scanError: String?
    private var toastTask: Task<Void, Never>?
    private var apiKey: String?
    private let keyProvider: () -> String?
    private let preferences: UserDefaults?

    init(transport: @escaping JevClassifier.Transport = { try await URLSession.shared.data(for: $0) },
         keyProvider: @escaping () -> String? = JevClassifier.resolveKey,
         openLaunchArgument: Bool = true, preferences: UserDefaults? = .standard) {
        gathering = GatheringEngine(transport: transport)
        self.preferences = preferences
        recents = (preferences?.stringArray(forKey: Self.recentsKey) ?? []).map { URL(fileURLWithPath: $0) }
        self.keyProvider = keyProvider
        apiKey = Self.normalizedKey(keyProvider())
        // `open LivingFolders.app --args /path/to/folder` opens straight into that folder.
        if openLaunchArgument, let path = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) {
            let url = URL(fileURLWithPath: path)
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { open(url) }
        }
    }

    var gathered: [FileItem] { items.filter { memberships[$0.id]?.belongs == true } }
    var scattered: [FileItem] { items.filter { memberships[$0.id]?.belongs != true } }
    var folderTitle: String { prompt.trimmingCharacters(in: .whitespaces).isEmpty ? "Your living folder" : prompt.trimmingCharacters(in: .whitespaces) }
    var canApprove: Bool {
        root != nil && scanError == nil && gathering.isCurrent && !gathered.isEmpty &&
        !isThinking && !isMoving && ShellMover.folderName(from: prompt) != nil
    }
    var planIsCurrent: Bool { plan != nil && canApprove && planGeneration == gathering.generation }

    // MARK: Folder

    func chooseFolder(creating: Bool = false) {
        guard !isMoving else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = root
        panel.prompt = "Open"
        panel.message = creating ? "Use New Folder to create a folder, then open it." : "Choose the folder Living Folders should work inside."
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func open(_ url: URL) {
        guard !isMoving else { return }
        closeFolder()
        let root = url.standardizedFileURL.resolvingSymlinksInPath()
        self.root = root
        let version = folderVersion
        do {
            watcher = try FolderWatcher(root: root) { [weak self] in
                Task { @MainActor in
                    guard let self, self.folderVersion == version, !self.isMoving else { return }
                    self.reload(debounce: true)
                }
            }
            rescan()
            recents.removeAll { $0.path == root.path }
            recents.insert(root, at: 0)
            recents = Array(recents.prefix(6))
            preferences?.set(recents.map(\.path), forKey: Self.recentsKey)
        } catch {
            scanError = "Could not watch \(root.lastPathComponent): \(error.localizedDescription)"
            show(scanError!, isError: true)
        }
    }

    func closeFolder() {
        guard !isMoving else { return }
        folderVersion += 1
        scanVersion += 1
        watcher?.stop()
        watcher = nil
        scanTask?.cancel()
        root = nil
        items = []
        isScanning = false
        scanError = nil
        reset()
    }

    func rescan() { reload(debounce: false) }

    private func reload(debounce: Bool) {
        guard let root, !isMoving else { return }
        scanTask?.cancel()
        scanVersion += 1
        let version = scanVersion
        isScanning = true
        scanError = nil
        plan = nil
        gathering.cancel()
        scanTask = Task { [weak self] in
            do {
                if debounce { try await Task.sleep(for: .milliseconds(120)) }
                try Task.checkCancellation()
                let snapshot = try await Task.detached(priority: .userInitiated) { try FolderScanner.scan(root) }.value
                guard let self, !Task.isCancelled, version == scanVersion else { return }
                items = snapshot
                isScanning = false
                classify(immediate: true)
            } catch {
                guard let self, !Task.isCancelled, version == scanVersion else { return }
                items = []
                isScanning = false
                gathering.cancel(clear: true)
                scanError = "Could not read \(root.lastPathComponent): \(error.localizedDescription)"
                show(scanError!, isError: true)
            }
        }
    }

    // MARK: Typing

    func promptChanged(from previous: String) {
        plan = nil
        lastResult = nil
        // Space and paste dispatch immediately; unfinished words wait for a short idle gap.
        let immediate = prompt.hasSuffix(" ") || prompt.count - previous.count > 1
        classify(immediate: immediate)
    }

    func usePreset(_ text: String) { prompt = text }

    private func classify(immediate: Bool) {
        guard !isScanning, !isMoving, scanError == nil else {
            gathering.cancel()
            return
        }
        gathering.update(prompt: prompt, items: items, apiKey: apiKey, immediate: immediate)
    }

    func credentialsChanged() {
        apiKey = Self.normalizedKey(keyProvider())
        plan = nil
        lastResult = nil
        classify(immediate: true)
    }

    private static func normalizedKey(_ key: String?) -> String? {
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return nil }
        return key
    }

    func reset(keepPrompt: Bool = false) {
        gathering.cancel(clear: true)
        plan = nil
        lastResult = nil
        if !keepPrompt { prompt = "" }
        if !isScanning { classify(immediate: true) }
    }

    // MARK: Moving

    func prepareApproval() {
        guard let root, canApprove else { return }
        do {
            plan = try ShellMover.plan(root: root, prompt: prompt, items: gathered)
            planGeneration = gathering.generation
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    func approve() async {
        guard let plan, planIsCurrent else { return }
        isMoving = true
        gathering.cancel()
        do {
            let result = try await ShellMover.execute(plan)
            self.plan = nil
            prompt = ""
            gathering.cancel(clear: true)
            lastResult = result
            show("\(result.moved.count) moved · \(result.elapsedMilliseconds) ms")
        } catch {
            self.plan = nil
            show(error.localizedDescription, isError: true)
        }
        isMoving = false
        rescan()
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
