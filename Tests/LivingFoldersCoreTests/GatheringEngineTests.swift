import XCTest
@testable import LivingFoldersCore

@MainActor
final class GatheringEngineTests: XCTestCase {
    private func items(_ root: String = "/one", count: Int = 2, modified: Date = .distantPast) -> [FileItem] {
        (0..<count).map {
            let url = URL(fileURLWithPath: "\(root)/file-\($0).pdf")
            return FileItem(url: url, name: url.lastPathComponent, ext: "pdf", isDirectory: false, size: 1, modified: modified)
        }
    }

    func testNoKeyAndShortPromptNeverCallTransport() async throws {
        let engine = GatheringEngine { _ in
            XCTFail("Must not contact transport")
            throw URLError(.badURL)
        }
        engine.update(prompt: "Trip", items: items(), apiKey: nil, immediate: true)
        XCTAssertFalse(engine.isCurrent)
        engine.update(prompt: "ab", items: items(), apiKey: "mock", immediate: true)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertFalse(engine.isThinking)
        XCTAssertTrue(engine.memberships.isEmpty)
    }

    func testCacheInvalidatesForChangedFilesAndCredentials() async throws {
        let mock = EngineTransport()
        let engine = GatheringEngine { try await mock.send($0) }
        engine.update(prompt: "Trip", items: items(), apiKey: "mock", immediate: true)
        try await wait { engine.isCurrent }
        engine.update(prompt: "Trip ", items: items(), apiKey: "mock", immediate: true)
        XCTAssertTrue(engine.isCurrent)
        var count = await mock.count
        XCTAssertEqual(count, 1)
        engine.update(prompt: "Trip", items: items(modified: Date()), apiKey: "mock", immediate: true)
        try await wait { engine.isCurrent }
        count = await mock.count
        XCTAssertEqual(count, 2)
        engine.update(prompt: "Trip", items: items(), apiKey: "changed", immediate: true)
        try await wait { engine.isCurrent }
        count = await mock.count
        XCTAssertEqual(count, 3)
    }

    func testLatestIntentWinsEvenIfTransportIgnoresCancellation() async throws {
        let mock = EngineTransport()
        let engine = GatheringEngine { try await mock.send($0) }
        engine.update(prompt: "Slow trip", items: items(), apiKey: "mock", immediate: true)
        try await Task.sleep(for: .milliseconds(20))
        engine.update(prompt: "Obsolete", items: items(), apiKey: "mock", immediate: true)
        engine.update(prompt: "Latest", items: items("/two"), apiKey: "mock", immediate: true)
        try await wait { engine.isCurrent }
        XCTAssertEqual(Set(engine.memberships.keys), Set(items("/two").map(\.id)))
        let names = await mock.names
        XCTAssertEqual(names, ["Slow trip", "Latest"])
        let peak = await mock.peak
        XCTAssertEqual(peak, 1)
    }

    func testIdenticalInflightNameSharesRequest() async throws {
        let mock = EngineTransport()
        let engine = GatheringEngine { try await mock.send($0) }
        engine.update(prompt: "Slow trip", items: items(), apiKey: "mock", immediate: true)
        try await Task.sleep(for: .milliseconds(20))
        engine.update(prompt: "Slow   trip ", items: items(), apiKey: "mock", immediate: true)
        try await wait { engine.isCurrent }
        let count = await mock.count
        XCTAssertEqual(count, 1)
    }

    func testClearCancelsAndRejectsLateResults() async throws {
        let mock = EngineTransport()
        let engine = GatheringEngine { try await mock.send($0) }
        engine.update(prompt: "Slow trip", items: items(), apiKey: "mock", immediate: true)
        try await Task.sleep(for: .milliseconds(20))
        engine.update(prompt: "", items: items(), apiKey: "mock", immediate: true)
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertTrue(engine.memberships.isEmpty)
        XCTAssertFalse(engine.isThinking)
        XCTAssertFalse(engine.isCurrent)
    }

    func testBatchesAppearBeforeCompletionButCannotBeApproved() async throws {
        let mock = EngineTransport()
        let engine = GatheringEngine { try await mock.send($0) }
        engine.update(prompt: "Progress", items: items(count: 81), apiKey: "mock", immediate: true)
        try await wait { !engine.memberships.isEmpty }
        XCTAssertTrue(engine.isThinking)
        XCTAssertFalse(engine.isCurrent)
        try await wait { engine.isCurrent }
        XCTAssertEqual(engine.memberships.count, 81)
    }

    func testFailureClearsOldMatches() async throws {
        let mock = EngineTransport()
        let engine = GatheringEngine { try await mock.send($0) }
        engine.update(prompt: "Trip", items: items(), apiKey: "mock", immediate: true)
        try await wait { engine.isCurrent }
        engine.update(prompt: "Fail", items: items(), apiKey: "mock", immediate: true)
        try await wait { engine.error != nil }
        XCTAssertTrue(engine.memberships.isEmpty)
        XCTAssertFalse(engine.isCurrent)
        XCTAssertFalse(engine.hasSuccessfulResponse)
    }

    private func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(condition(), "Timed out waiting for engine state")
    }
}

private actor EngineTransport {
    var count = 0
    var names: [String] = []
    var active = 0
    var peak = 0

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let payload = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let state = try JSONSerialization.jsonObject(with: Data((payload["state"] as! String).utf8)) as! [String: Any]
        let name = state["virtual_folder"] as! String
        let questions = payload["questions"] as! [String: Any]
        names.append(name)
        count += 1
        active += 1
        peak = max(peak, active)
        defer { active -= 1 }
        let delay = name.hasPrefix("Slow") || questions.count == 1 ? 0.12 : 0.01
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { continuation.resume() }
        }
        if name == "Fail" { throw URLError(.notConnectedToInternet) }
        let answers = Dictionary(uniqueKeysWithValues: questions.keys.map { ($0, ["noul": 0.9]) })
        return (
            try JSONSerialization.data(withJSONObject: ["answers": answers]),
            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }
}
