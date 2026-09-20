import XCTest
import SwiftUI
@testable import LivingFolders
import LivingFoldersCore

@MainActor
final class WorkspaceTests: XCTestCase {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.resolvingSymlinksInPath()
    }

    private func model() -> WorkspaceModel {
        WorkspaceModel(transport: { request in
            let payload = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let questions = payload["questions"] as! [String: Any]
            let answers = Dictionary(uniqueKeysWithValues: questions.keys.map { ($0, ["noul": 0.9]) })
            try await Task.sleep(for: .milliseconds(10))
            return (try JSONSerialization.data(withJSONObject: ["answers": answers]),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }, keyProvider: { "test-only" }, openLaunchArgument: false, preferences: nil)
    }

    func testWatcherReclassifiesAndInvalidatesApprovalWithoutTyping() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.txt")
        try Data("one".utf8).write(to: first)
        let model = model()
        defer { model.closeFolder() }
        model.open(root)
        model.prompt = "Trip"
        try await wait { model.canApprove }
        model.prepareApproval()
        XCTAssertNotNil(model.plan)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Trip").path))
        try Data("two".utf8).write(to: root.appendingPathComponent("second.txt"))
        try await wait { model.items.count == 2 && model.canApprove }
        XCTAssertNil(model.plan)
        XCTAssertEqual(model.gathered.count, 2)
        XCTAssertEqual(model.mode, .jev)
        model.prepareApproval()
        model.prompt = "a"
        XCTAssertNil(model.plan)
        XCTAssertFalse(model.canApprove)
        XCTAssertTrue(model.memberships.isEmpty)
    }

    func testSwitchAndCloseIgnoreOldFolderEvents() async throws {
        let first = try directory()
        let second = try directory()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let model = model()
        model.open(first)
        model.prompt = "Trip"
        model.open(second)
        try Data().write(to: first.appendingPathComponent("old.txt"))
        try Data().write(to: second.appendingPathComponent("new.txt"))
        model.prompt = "Trip"
        try await wait { model.canApprove }
        XCTAssertEqual(model.items.map(\.name), ["new.txt"])
        model.closeFolder()
        try Data().write(to: second.appendingPathComponent("late.txt"))
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertNil(model.root)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.memberships.isEmpty)
    }

    func testMoveRequiresApprovalAndRescansAfterward() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("first.txt")
        try Data("one".utf8).write(to: file)
        let model = model()
        defer { model.closeFolder() }
        model.open(root)
        model.prompt = "Trip"
        try await wait { model.canApprove }
        await model.approve()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        model.prepareApproval()
        await model.approve()
        try await wait { !model.isScanning }
        XCTAssertEqual(model.lastResult?.moved.count, 1)
        XCTAssertEqual(model.items.map(\.name), ["Trip"])
        XCTAssertTrue(model.prompt.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Trip/first.txt").path))
    }

    func testAllFilesBeyondOldDisplayLimitAreGatheredAndScrollable() async throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<125 { try Data().write(to: root.appendingPathComponent("\(index).txt")) }
        let model = model()
        defer { model.closeFolder() }
        model.open(root)
        model.prompt = "Trip"
        try await wait { model.canApprove }
        XCTAssertEqual(model.items.count, 125)
        XCTAssertEqual(model.gathered.count, 125)
        let height = Layout.height(count: 125, width: 300)
        let layout = Layout.grid(count: 125, in: CGRect(x: 0, y: 0, width: 300, height: height))
        XCTAssertEqual(layout.points.count, 125)
        XCTAssertGreaterThan(height, 600)
        XCTAssertLessThan(layout.points.last!.y, height)
    }

    func testMockedWorkspaceSnapshot() async throws {
        guard let path = ProcessInfo.processInfo.environment["LIVING_FOLDERS_TEST_SNAPSHOT"] else {
            throw XCTSkip("Set LIVING_FOLDERS_TEST_SNAPSHOT to capture the mocked workspace")
        }
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["Flight to Tokyo.pdf", "Kyoto hotel.pdf", "Japan itinerary.key", "Passport.pdf", "Receipt.pdf", "Travel notes.md", "Photo.jpg", "Python tutorial.pdf"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        let model = WorkspaceModel(transport: { request in
            let payload = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let questions = payload["questions"] as! [String: Any]
            let answers = Dictionary(uniqueKeysWithValues: questions.keys.map { ($0, ["noul": Int($0)! % 2 == 0 ? 0.9 : 0.1]) })
            return (try JSONSerialization.data(withJSONObject: ["answers": answers]),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }, keyProvider: { "mock-only" }, openLaunchArgument: false, preferences: nil)
        defer { model.closeFolder() }
        model.open(root)
        model.prompt = "Stuff for my Japan trip"
        try await wait { model.canApprove }
        _ = NSApplication.shared
        let view = NSHostingView(rootView: ZStack { Backdrop(); WorkspaceView(model: model) }.preferredColorScheme(.light))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderBack(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(600))
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        XCTAssertEqual(model.gathered.count, 4)
    }

    private func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition(), "Timed out waiting for workspace state")
    }
}
