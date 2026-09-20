import XCTest
@testable import LivingFoldersCore

final class JevClassifierTests: XCTestCase {
    func testEveryItemIsScoredInBoundedBatches() async throws {
        let probe = RequestProbe()
        let items = (0..<95).map { index in
            let url = URL(fileURLWithPath: "/private/test/file-\(index).pdf")
            return FileItem(url: url, name: url.lastPathComponent, ext: "pdf", isDirectory: false, size: 1, modified: .distantPast)
        }
        let classifier = JevClassifier(apiKey: "test-only", transport: { request in
            try await probe.respond(to: request)
        })
        let result = try await classifier.classify(folderName: "Travel", items: items)
        XCTAssertEqual(result.map(\.id), items.map(\.id))
        XCTAssertTrue(result.allSatisfy(\.belongs))
        let stats = await probe.statistics()
        XCTAssertEqual(stats.sizes.sorted(), [15, 40, 40])
        XCTAssertLessThanOrEqual(stats.peak, 2)
        XCTAssertFalse(stats.containsPrivatePath)
    }

    func testEmptyCollectionMakesNoRequest() async throws {
        let classifier = JevClassifier(apiKey: "test-only", transport: { _ in
            XCTFail("Empty collections must not make requests")
            throw URLError(.badURL)
        })
        let result = try await classifier.classify(folderName: "Travel", items: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testUnauthorizedAndMalformedScoresFailClosed() async throws {
        let url = URL(fileURLWithPath: "/test/a.pdf")
        let item = FileItem(url: url, name: "a.pdf", ext: "pdf", isDirectory: false, size: 1, modified: .distantPast)
        for status in [401, 403, 429, 500] {
            let classifier = JevClassifier(apiKey: "test-only", transport: { request in
                (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
            })
            do {
                _ = try await classifier.classify(folderName: "Travel", items: [item])
                XCTFail("HTTP \(status) must fail")
            } catch { XCTAssertTrue(error is JevError) }
        }
        for value: Any in [true, -0.1, 1.1, "0.9"] {
            XCTAssertThrowsError(try JevClassifier.parse(items: [item], result: ["answers": ["0": ["noul": value]]]))
        }
        XCTAssertThrowsError(try JevClassifier.parse(items: [item], result: ["answers": [:]]))
    }
}

private actor RequestProbe {
    var active = 0
    var peak = 0
    var sizes: [Int] = []
    var containsPrivatePath = false

    func statistics() -> (sizes: [Int], peak: Int, containsPrivatePath: Bool) {
        (sizes, peak, containsPrivatePath)
    }

    func respond(to request: URLRequest) async throws -> (Data, URLResponse) {
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let questions = try XCTUnwrap(payload["questions"] as? [String: Any])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only")
        containsPrivatePath = containsPrivatePath || String(decoding: request.httpBody!, as: UTF8.self).contains("private")
        sizes.append(questions.count)
        active += 1
        peak = max(peak, active)
        defer { active -= 1 }
        try await Task.sleep(for: .milliseconds(10))
        let answers = Dictionary(uniqueKeysWithValues: questions.keys.map { ($0, ["noul": 0.9]) })
        let data = try JSONSerialization.data(withJSONObject: ["answers": answers])
        return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
