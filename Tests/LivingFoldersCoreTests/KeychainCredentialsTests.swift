import XCTest
@testable import LivingFoldersCore

final class KeychainCredentialsTests: XCTestCase {
    private var previousService = ""

    override func setUp() {
        super.setUp()
        previousService = KeychainCredentials.service
        KeychainCredentials.service = "ai.typesafe.LivingFolders.test.\(UUID().uuidString)"
        try? KeychainCredentials.delete()
    }

    override func tearDown() {
        try? KeychainCredentials.delete()
        KeychainCredentials.service = previousService
        super.tearDown()
    }

    func testSaveLoadDeleteRoundTrip() throws {
        XCTAssertNil(KeychainCredentials.load())
        try KeychainCredentials.save("sk-test-roundtrip")
        XCTAssertEqual(KeychainCredentials.load(), "sk-test-roundtrip")
        try KeychainCredentials.save("sk-replaced")
        XCTAssertEqual(KeychainCredentials.load(), "sk-replaced")
        try KeychainCredentials.delete()
        XCTAssertNil(KeychainCredentials.load())
    }

    func testEmptySaveDeletes() throws {
        try KeychainCredentials.save("sk-temp")
        try KeychainCredentials.save("   ")
        XCTAssertNil(KeychainCredentials.load())
    }

    func testResolveKeyUsesKeychainAsStored() throws {
        try KeychainCredentials.save("sk-from-keychain")
        unsetenv("TYPESAFE_API_KEY")
        // Avoid .env by pointing at a temp bundle with no repo root.
        let orphan = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let resolved = JevClassifier.resolveKeyWithSource(bundleURL: orphan)
        XCTAssertEqual(resolved?.key, "sk-from-keychain")
        XCTAssertEqual(resolved?.source, .stored)
    }

    func testMigrateUserDefaultsIntoKeychain() throws {
        let defaults = UserDefaults(suiteName: "ai.typesafe.LivingFolders.test.defaults.\(UUID().uuidString)")!
        defaults.set("sk-legacy", forKey: "TYPESAFE_API_KEY")
        KeychainCredentials.migrateFromUserDefaultsIfNeeded(defaults: defaults)
        XCTAssertEqual(KeychainCredentials.load(), "sk-legacy")
        XCTAssertNil(defaults.string(forKey: "TYPESAFE_API_KEY"))
    }
}
