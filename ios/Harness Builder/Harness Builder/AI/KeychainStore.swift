//
//  KeychainStore.swift
//  Harness Builder
//
//  Keeps the user's Anthropic key in the iOS Keychain: this device only, no
//  iCloud sync, never in the saved data, a backup, an export or the repo.
//

import Foundation
import Security

struct KeychainStore {
    enum KeyError: LocalizedError, Equatable {
        case empty
        case hasSpaces
        case status(Int32)

        var errorDescription: String? {
            switch self {
            case .empty: return "Paste your key first."
            case .hasSpaces: return "A key has no spaces or line breaks. Check what was pasted."
            case .status(let code): return "The key couldn't be saved on this device (error \(code))."
            }
        }
    }

    let service: String
    let account: String

    init(service: String = "BagelBytez.Harness-Builder.anthropic", account: String = "api-key") {
        self.service = service
        self.account = account
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    /// Saves the key, replacing any earlier one.
    func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KeyError.empty }
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { throw KeyError.hasSpaces }

        delete()
        var add = query
        add[kSecValueData as String] = Data(trimmed.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyError.status(status) }
    }

    func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var hasKey: Bool { read() != nil }

    func delete() {
        SecItemDelete(query as CFDictionary)
    }

    /// What to show on screen: never the key, only its last four characters.
    static func masked(_ key: String) -> String {
        "••••" + String(key.suffix(4))
    }
}
