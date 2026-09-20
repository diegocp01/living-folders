import Foundation
import Security

/// macOS Keychain store for the user's TypeSafe/Jev API key (BYOK).
///
/// Never log or print the key. Prefer this over UserDefaults for the shipped app;
/// `.env` / process environment remain higher-priority for local checkouts.
public enum KeychainCredentials {
    public static let account = "TYPESAFE_API_KEY"
    /// Overridable for tests so suites do not collide with the real app item.
    public static var service = "ai.typesafe.LivingFolders"

    public enum StoreError: LocalizedError {
        case unexpectedStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return "Keychain error (\(status))."
            }
        }
    }

    public static func load() -> String? {
        migrateFromUserDefaultsIfNeeded()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    public static func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try delete()
            return
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return }
        if update == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess else { throw StoreError.unexpectedStatus(status) }
            return
        }
        throw StoreError.unexpectedStatus(update)
    }

    public static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(status)
        }
    }

    /// One-time move from the old UserDefaults / AppStorage slot into Keychain.
    public static func migrateFromUserDefaultsIfNeeded(
        defaults: UserDefaults = .standard,
        defaultsKey: String = "TYPESAFE_API_KEY"
    ) {
        guard let legacy = defaults.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !legacy.isEmpty else { return }
        // Only migrate when Keychain has nothing yet.
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let existing = SecItemCopyMatching(probe as CFDictionary, &item)
        if existing == errSecSuccess {
            defaults.removeObject(forKey: defaultsKey)
            return
        }
        try? save(legacy)
        defaults.removeObject(forKey: defaultsKey)
    }
}
