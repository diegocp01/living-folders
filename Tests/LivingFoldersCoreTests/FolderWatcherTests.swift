import XCTest
@testable import LivingFoldersCore

@MainActor
final class FolderWatcherTests: XCTestCase {
    func testWatchesCreationModificationRenameAndRemoval() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let changes = ChangeCounter()
        let watcher = try FolderWatcher(root: root) { Task { @MainActor in changes.count += 1 } }
        defer { watcher.stop() }
        let original = root.appendingPathComponent("notes.txt")
        let renamed = root.appendingPathComponent("renamed.txt")
        try await expectChange(changes) { try Data("one".utf8).write(to: original) }
        try await expectChange(changes) { try Data("two plus".utf8).write(to: original) }
        try await expectChange(changes) { try FileManager.default.moveItem(at: original, to: renamed) }
        try await expectChange(changes) { try FileManager.default.removeItem(at: renamed) }
        watcher.stop()
        try await Task.sleep(for: .milliseconds(200))
        let stopped = changes.count
        try Data().write(to: original)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(changes.count, stopped)
    }

    private func expectChange(_ changes: ChangeCounter, action: () throws -> Void) async throws {
        try await Task.sleep(for: .milliseconds(200))
        let before = changes.count
        try action()
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while changes.count == before, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertGreaterThan(changes.count, before)
    }
}

@MainActor
private final class ChangeCounter {
    var count = 0
}
