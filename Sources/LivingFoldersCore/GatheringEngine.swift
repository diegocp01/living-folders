import Foundation
import Observation

@MainActor @Observable
public final class GatheringEngine {
    public private(set) var memberships: [String: Membership] = [:]
    public private(set) var isThinking = false
    public private(set) var isCurrent = false
    public private(set) var hasSuccessfulResponse = false
    public private(set) var generation = 0
    public private(set) var error: String?
    public private(set) var status = "Name the folder. It fills as you type."

    private struct Request {
        let generation: Int
        let name: String
        let items: [FileItem]
        let key: String
    }

    private let transport: JevClassifier.Transport
    private var snapshot: [FileItem] = []
    private var credential = ""
    private var requestName = ""
    private var activeGeneration = -1
    private var cache: [String: [Membership]] = [:]
    private var cacheOrder: [String] = []
    private var pending: Request?
    private var delay: Task<Void, Never>?
    private var worker: Task<Void, Never>?
    private var flight: Task<[Membership], Error>?

    public init(transport: @escaping JevClassifier.Transport = { try await URLSession.shared.data(for: $0) }) {
        self.transport = transport
    }

    public func cancel(clear: Bool = false) {
        generation += 1
        delay?.cancel()
        flight?.cancel()
        pending = nil
        isThinking = false
        isCurrent = false
        error = nil
        if clear { memberships = [:] }
    }

    public func update(prompt: String, items: [FileItem], apiKey: String?, immediate: Bool = false) {
        let name = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if requestName == name, snapshot == items, credential == key,
           isCurrent || (isThinking && activeGeneration == generation) { return }
        cancel()
        requestName = name
        if snapshot != items || credential != key {
            cache.removeAll()
            cacheOrder.removeAll()
            memberships = [:]
        }
        if credential != key { hasSuccessfulResponse = false }
        snapshot = items
        credential = key
        guard !key.isEmpty else {
            memberships = [:]
            status = "Add your Jev API key in Settings to start gathering."
            return
        }
        guard name.count >= 3 else {
            memberships = [:]
            status = name.isEmpty ? "Name the folder. It fills as you type." : "Keep typing. The idea is still too short."
            return
        }
        guard !items.isEmpty else {
            memberships = [:]
            status = "This folder is empty. New items will appear automatically."
            return
        }
        if let cached = cache[name] {
            memberships = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
            isCurrent = true
            status = "\(cached.filter(\.belongs).count) gathered · cached · watching for changes"
            return
        }
        isThinking = true
        status = "Jev is reading the folder name…"
        let request = Request(generation: generation, name: name, items: items, key: key)
        delay = Task { [weak self] in
            if !immediate {
                do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
            }
            guard let self, !Task.isCancelled, request.generation == generation else { return }
            pending = request
            startWorker()
        }
    }

    private func startWorker() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while let self, let request = pending {
                pending = nil
                await run(request)
            }
            self?.worker = nil
        }
    }

    private func run(_ request: Request) async {
        activeGeneration = request.generation
        let started = ContinuousClock.now
        let classifier = JevClassifier(apiKey: request.key, transport: transport)
        let onBatch: JevClassifier.Progress = { [weak self] batch in
            await self?.receive(batch, generation: request.generation)
        }
        let task = Task {
            try await classifier.classify(folderName: request.name, items: request.items, onBatch: onBatch)
        }
        flight = task
        do {
            let result = try await task.value
            guard request.generation == generation, !task.isCancelled else { return }
            memberships = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
            isThinking = false
            isCurrent = true
            cache[request.name] = result
            cacheOrder.append(request.name)
            if cacheOrder.count > 32 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
            let elapsed = started.duration(to: .now).components
            let ms = elapsed.seconds * 1000 + elapsed.attoseconds / 1_000_000_000_000_000
            status = "\(result.filter(\.belongs).count) gathered · \(ms) ms · watching for changes"
        } catch {
            guard request.generation == generation else { return }
            memberships = [:]
            isThinking = false
            isCurrent = false
            self.error = error.localizedDescription
            status = error.localizedDescription
            hasSuccessfulResponse = false
        }
    }

    private var receivingGeneration = -1

    private func receive(_ batch: [Membership], generation: Int) {
        guard generation == self.generation else { return }
        if receivingGeneration != generation {
            memberships = [:]
            receivingGeneration = generation
        }
        for value in batch { memberships[value.id] = value }
        hasSuccessfulResponse = true
        status = "Scored \(memberships.count) of \(snapshot.count) items…"
    }
}
