import XCTest
@testable import LivingFoldersCore

final class ClassifierTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func item(_ name: String, daysAgo: Double = 30, directory: Bool = false) -> FileItem {
        let url = URL(fileURLWithPath: "/tmp/root/\(name)")
        return FileItem(url: url, name: name, ext: directory ? "" : url.pathExtension.lowercased(), isDirectory: directory, size: 1, modified: now.addingTimeInterval(-daysAgo * 86_400))
    }

    func members(_ prompt: String, _ items: [FileItem]) -> Set<String> {
        Set(LocalClassifier().classify(folderName: prompt, items: items, now: now).filter(\.belongs).map { URL(fileURLWithPath: $0.id).lastPathComponent })
    }

    func testFileTypeVocabulary() {
        let items = [item("IMG_2031.heic"), item("Screenshot 2026-09-01.png"), item("Invoice.pdf"), item("song.mp3")]
        XCTAssertEqual(members("Photos", items), ["IMG_2031.heic", "Screenshot 2026-09-01.png"])
        XCTAssertEqual(members("all my screenshots", items), ["Screenshot 2026-09-01.png"])
        XCTAssertEqual(members("music", items), ["song.mp3"])
    }

    func testFilenameSynonyms() {
        let items = [item("Flight to Tokyo.pdf"), item("Kyoto hotel.pdf"), item("2025 taxes.xlsx"), item("Milo at the beach.jpg")]
        XCTAssertEqual(members("Stuff for my Japan trip", items), ["Flight to Tokyo.pdf", "Kyoto hotel.pdf"])
        XCTAssertEqual(members("Tax documents", items), ["2025 taxes.xlsx"])
        XCTAssertEqual(members("Milo", items), ["Milo at the beach.jpg"])
    }

    func testTimeWindows() {
        let items = [item("today.txt", daysAgo: 0.2), item("lastweek.txt", daysAgo: 5), item("ancient.txt", daysAgo: 400)]
        XCTAssertEqual(members("Things from this week", items), ["today.txt", "lastweek.txt"])
        XCTAssertEqual(members("Old stuff", items), ["ancient.txt"])
    }

    func testFoldersVersusFiles() {
        let items = [item("Projects", directory: true), item("notes.md")]
        XCTAssertEqual(members("Folders", items), ["Projects"])
        XCTAssertEqual(members("Markdown files", items), ["notes.md"])
    }

    func testConfidenceIsBoundedAndStable() {
        let result = LocalClassifier().classify(folderName: "receipts", items: [item("Camera invoice.pdf"), item("dog.jpg")], now: now)
        XCTAssertEqual(result.count, 2)
        for membership in result { XCTAssert((0...1).contains(membership.confidence)) }
        XCTAssertGreaterThan(result[0].confidence, result[1].confidence)
    }

    func testJevPayloadAndParsing() throws {
        let items = [item("a.pdf"), item("b.pdf")]
        let payload = JevClassifier.payload(folderName: "Taxes", items: items)
        XCTAssertEqual(payload["model"] as? String, "jev-latest")
        XCTAssertEqual((payload["questions"] as? [String: Any])?.count, 2)
        let parsed = try JevClassifier.parse(items: items, result: ["answers": [items[0].id: ["noul": 0.9], items[1].id: ["noul": 0.2]]])
        XCTAssertEqual(parsed.map(\.belongs), [true, false])
        XCTAssertThrowsError(try JevClassifier.parse(items: items, result: ["answers": [items[0].id: ["noul": 1.4]]]))
    }
}
