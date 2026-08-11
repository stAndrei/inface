import Foundation
import Security

public enum ExchangeCredentialError: Error, Equatable, Sendable {
    case notFound
    case keychainFailure
}

public protocol ExchangeCredentialStoring: Sendable {
    func savePassword(_ password: String, for username: String) throws
    func loadPassword(for username: String) throws -> String
    func deletePassword(for username: String) throws
    func hasCredentials(for username: String) -> Bool
}

public final class ExchangeCredentialStore: ExchangeCredentialStoring, @unchecked Sendable {
    public static let serviceName = "ru.inface.exchange"

    public init() {}

    public func savePassword(_ password: String, for username: String) throws {
        try deletePassword(for: username)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: username,
            kSecValueData as String: Data(password.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ExchangeCredentialError.keychainFailure
        }
    }

    public func loadPassword(for username: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
            throw ExchangeCredentialError.notFound
        }
        return password
    }

    public func deletePassword(for username: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: username
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ExchangeCredentialError.keychainFailure
        }
    }

    public func hasCredentials(for username: String) -> Bool {
        (try? loadPassword(for: username)) != nil
    }
}

public final class MockExchangeCredentialStore: ExchangeCredentialStoring, @unchecked Sendable {
    private var passwords: [String: String] = [:]

    public init() {}

    public func savePassword(_ password: String, for username: String) throws {
        passwords[username] = password
    }

    public func loadPassword(for username: String) throws -> String {
        guard let password = passwords[username] else {
            throw ExchangeCredentialError.notFound
        }
        return password
    }

    public func deletePassword(for username: String) throws {
        passwords.removeValue(forKey: username)
    }

    public func hasCredentials(for username: String) -> Bool {
        passwords[username] != nil
    }
}
