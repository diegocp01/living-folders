import XCTest
@testable import LivingFoldersCore

final class UpdaterTests: XCTestCase {
    // MARK: - needsUpdate (pure, no network, no git)

    func testSameRevisionIsUpToDate() {
        XCTAssertFalse(Updater.needsUpdate(local: "abc123", remote: "abc123"))
    }

    func testDifferentRevisionNeedsUpdate() {
        XCTAssertTrue(Updater.needsUpdate(local: "abc123", remote: "def456"))
    }

    func testEmptyRevisionNeverNeedsUpdate() {
        XCTAssertFalse(Updater.needsUpdate(local: "", remote: "def456"))
        XCTAssertFalse(Updater.needsUpdate(local: "abc123", remote: ""))
        XCTAssertFalse(Updater.needsUpdate(local: "", remote: ""))
    }

    // MARK: - findSourceDir (filesystem only, no network)

    func testFindsCheckoutAboveAppBundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lf-test-\(UUID().uuidString)")
        let gitDir = root.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // build/LivingFolders.app -> repo root holds .git
        let bundle = root.appendingPathComponent("build/LivingFolders.app")
        XCTAssertEqual(Updater.findSourceDir(from: bundle)?.path, root.path)
    }

    func testReturnsNilWithoutGitCheckout() {
        let bundle = URL(fileURLWithPath: "/tmp/definitely-not-a-checkout/LivingFolders.app")
        XCTAssertNil(Updater.findSourceDir(from: bundle))
    }

    func testFindsCheckoutFromNestedDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lf-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let deep = root.appendingPathComponent("a/b/c")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertEqual(Updater.findSourceDir(from: deep)?.path, root.path)
    }
}
