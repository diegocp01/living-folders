import XCTest
@testable import LivingFoldersCore

final class ShellMoverTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("living-folders-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["Flight to Tokyo.pdf", "it's a receipt.pdf", "dog.jpg"] {
            try Data("x".utf8).write(to: root.appendingPathComponent(name))
        }
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testFolderNameSanitising() {
        XCTAssertEqual(ShellMover.folderName(from: "  Stuff for my Japan trip "), "Stuff for my Japan trip")
        XCTAssertEqual(ShellMover.folderName(from: "../etc/passwd"), "etc-passwd")
        XCTAssertEqual(ShellMover.folderName(from: "a/b:c"), "a-b-c")
        XCTAssertNil(ShellMover.folderName(from: "..."))
    }

    func testPlanUsesMkdirAndMvWithQuoting() throws {
        let items = try FolderScanner.scan(root)
        let plan = try ShellMover.plan(root: root, prompt: "Japan trip", items: items.filter { $0.name != "dog.jpg" })
        XCTAssertEqual(plan.commands.count, 2)
        XCTAssertEqual(plan.commands[0].executable, "/bin/mkdir")
        XCTAssertEqual(plan.commands[1].executable, "/bin/mv")
        XCTAssertEqual(plan.commands[1].arguments.first, "-n")
        XCTAssert(plan.commands[1].display.contains("'/") || plan.commands[1].display.contains("Flight"))
        XCTAssert(plan.commands[1].display.contains("'\\''"), "apostrophes must be shell-quoted")
    }

    func testExecuteMovesOnlySelectedFiles() async throws {
        let items = try FolderScanner.scan(root)
        let plan = try ShellMover.plan(root: root, prompt: "Japan trip", items: items.filter { $0.ext == "pdf" })
        let result = try await ShellMover.execute(plan)

        XCTAssertEqual(result.moved.count, 2)
        XCTAssert(FileManager.default.fileExists(atPath: root.appendingPathComponent("Japan trip/Flight to Tokyo.pdf").path))
        XCTAssert(FileManager.default.fileExists(atPath: root.appendingPathComponent("Japan trip/it's a receipt.pdf").path))
        XCTAssert(FileManager.default.fileExists(atPath: root.appendingPathComponent("dog.jpg").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Flight to Tokyo.pdf").path))
        XCTAssertEqual(result.log.filter { $0.hasPrefix("$ /bin/") }.count, 2)

        let after = try FolderScanner.scan(root)
        XCTAssertEqual(Set(after.map(\.name)), ["Japan trip", "dog.jpg"])
        XCTAssert(after.first { $0.name == "Japan trip" }!.isDirectory)
    }

    func testExistingDestinationIsNeverMovedIntoItself() throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Japan trip"), withIntermediateDirectories: true)
        let items = try FolderScanner.scan(root)
        let plan = try ShellMover.plan(root: root, prompt: "Japan trip", items: items)
        XCTAssertFalse(plan.items.contains { $0.name == "Japan trip" })
    }
}
