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

    func testChangedSourceRequiresAnotherApproval() async throws {
        let items = try FolderScanner.scan(root)
        let plan = try ShellMover.plan(root: root, prompt: "Trip", items: items)
        try Data("changed after preview".utf8).write(to: items[0].url)
        do {
            _ = try await ShellMover.execute(plan)
            XCTFail("A stale preview must not move anything")
        } catch { XCTAssertTrue(error is MoveError) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: plan.destination.path))
        XCTAssertTrue(items.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
    }

    func testReplacementWithSameNameSizeAndDateInvalidatesPlan() async throws {
        let item = try XCTUnwrap(FolderScanner.scan(root).first)
        XCTAssertNotNil(item.fileIdentity)
        let plan = try ShellMover.plan(root: root, prompt: "Trip", items: [item])
        try FileManager.default.moveItem(at: item.url, to: root.appendingPathComponent("original"))
        try Data("x".utf8).write(to: item.url)
        try FileManager.default.setAttributes([.modificationDate: item.modified], ofItemAtPath: item.url.path)
        do {
            _ = try await ShellMover.execute(plan)
            XCTFail("A replaced file requires another approval")
        } catch { XCTAssertTrue(error is MoveError) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: plan.destination.path))
    }

    func testLargeMoveIsSplitIntoBoundedCommands() async throws {
        for index in 0..<130 { try Data().write(to: root.appendingPathComponent("\(index).txt")) }
        let items = try FolderScanner.scan(root)
        let plan = try ShellMover.plan(root: root, prompt: "Trip", items: items)
        XCTAssertEqual(plan.commands.count, 4)
        XCTAssertTrue(plan.commands.dropFirst().allSatisfy { $0.arguments.count <= 66 })
        let result = try await ShellMover.execute(plan)
        XCTAssertEqual(result.moved.count, items.count)
    }

    func testSymlinkDestinationCannotRedirectMoves() async throws {
        let items = try FolderScanner.scan(root)
        let elsewhere = root.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let plan = try ShellMover.plan(root: root, prompt: "Trip", items: items)
        try FileManager.default.createSymbolicLink(at: plan.destination, withDestinationURL: elsewhere)
        do {
            _ = try await ShellMover.execute(plan)
            XCTFail("A symlink destination must not be followed")
        } catch { XCTAssertTrue(error is MoveError) }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: elsewhere.path).isEmpty)
        XCTAssertTrue(items.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
    }

    func testCollisionFailsBeforeMovingOtherItems() async throws {
        let items = try FolderScanner.scan(root)
        let destination = root.appendingPathComponent("Trip")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: destination.appendingPathComponent(items[0].name))
        let plan = try ShellMover.plan(root: root, prompt: "Trip", items: items)
        do {
            _ = try await ShellMover.execute(plan)
            XCTFail("A collision must be reported rather than counted as moved")
        } catch { XCTAssertTrue(error is MoveError) }
        XCTAssertTrue(items.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
    }

    func testExistingDestinationIsNeverMovedIntoItself() throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Japan trip"), withIntermediateDirectories: true)
        let items = try FolderScanner.scan(root)
        let plan = try ShellMover.plan(root: root, prompt: "Japan trip", items: items)
        XCTAssertFalse(plan.items.contains { $0.name == "Japan trip" })
    }
}
