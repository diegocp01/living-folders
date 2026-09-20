import XCTest
@testable import LivingFoldersCore

final class UpdaterTests: XCTestCase {
    // MARK: - failure messages (pure, no network, no git)

    private func result(stdout: String = "", stderr: String = "", status: Int32 = 1) -> Updater.CommandResult {
        Updater.CommandResult(stdout: stdout, stderr: stderr, status: status)
    }

    func testReportsTheRealGitFailureNotAGenericOne() {
        // The exact shape git emits when the working tree is dirty.
        let git = result(stderr: """
        From https://github.com/diegocp01/living-folders
         * branch            main       -> FETCH_HEAD
        error: Your local changes to the following files would be overwritten by merge:
        \tPackage.swift
        Please commit your changes or stash them before you merge.
        """)
        let message = Updater.message(from: git, fallback: "git pull failed.")
        XCTAssertEqual(message, "Please commit your changes or stash them before you merge.")
    }

    func testSkipsGitProgressNoise() {
        // "From …" and "remote: …" are progress, never the reason for failure.
        let git = result(stderr: "From https://github.com/x/y\nremote: Counting objects: 100%")
        XCTAssertEqual(Updater.message(from: git, fallback: "fallback"), "fallback")
    }

    func testFallsBackWhenBothStreamsAreEmpty() {
        XCTAssertEqual(Updater.message(from: result(), fallback: "Downloading failed."), "Downloading failed.")
    }

    func testTruncatesRunawayOutput() {
        let message = Updater.message(from: result(stderr: String(repeating: "x", count: 500)), fallback: "f")
        XCTAssertEqual(message.count, 160)
        XCTAssertTrue(message.hasSuffix("…"))
    }

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
