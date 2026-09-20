import XCTest
@testable import LivingFoldersCore

final class EnvFileTests: XCTestCase {
    func testParseBasics() {
        let parsed = EnvFile.parse("""
        # a comment
        TYPESAFE_API_KEY=sk-test-123

        OTHER=1
        """)
        XCTAssertEqual(parsed["TYPESAFE_API_KEY"], "sk-test-123")
        XCTAssertEqual(parsed["OTHER"], "1")
    }

    func testParseQuotesExportAndEqualsInValue() {
        let parsed = EnvFile.parse("""
        export TYPESAFE_API_KEY="sk-quoted"
        SINGLE='sk-single'
        DATA=abc=def
           SPACED   =   padded
        NOEQUALS
        """)
        XCTAssertEqual(parsed["TYPESAFE_API_KEY"], "sk-quoted")
        XCTAssertEqual(parsed["SINGLE"], "sk-single")
        XCTAssertEqual(parsed["DATA"], "abc=def")
        XCTAssertEqual(parsed["SPACED"], "padded")
        XCTAssertNil(parsed["NOEQUALS"])
    }

    func testLoadMissingFileReturnsEmpty() {
        let missing = URL(fileURLWithPath: "/tmp/living-folders-test-nope-\(UUID().uuidString)")
        XCTAssertTrue(EnvFile.load(repoRoot: missing).isEmpty)
    }

    func testLoadReadsDotEnv() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "TYPESAFE_API_KEY=sk-from-env\n".write(to: dir.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        XCTAssertEqual(EnvFile.load(repoRoot: dir)["TYPESAFE_API_KEY"], "sk-from-env")
    }

    func testDotEnvTakesPriorityOverEnvironment() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try "TYPESAFE_API_KEY=sk-dotenv\n".write(to: dir.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        setenv("TYPESAFE_API_KEY", "sk-envvar", 1)
        defer { unsetenv("TYPESAFE_API_KEY") }
        let bundleURL = dir.appendingPathComponent("LivingFolders.app")
        let resolved = JevClassifier.resolveKeyWithSource(bundleURL: bundleURL)
        XCTAssertEqual(resolved?.key, "sk-dotenv")
        XCTAssertEqual(resolved?.source, .dotEnv)
    }
}
