import Foundation
import Security

/// Stores a WireGuard configuration in the shared Keychain group, not inside
/// NETunnelProviderProtocol.providerConfiguration or UserDefaults.
enum ProfileKeychain {
    static let service = "com.arturwarlord.freeroute"
    static let accessGroup = "group.com.arturwarlord.freeroute"

    enum StoreError: LocalizedError {
        case invalidText
        case status(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidText:
                return "Не удалось закодировать конфигурацию VPN."
            case .status(let code):
                return "Не удалось безопасно сохранить профиль VPN в Keychain (код \(code)). Проверь App Group в настройках Apple Developer."
            }
        }
    }

    /// Saves a config under a new account name and returns its persistent reference.
    static func save(_ configuration: String, profileName: String) throws -> Data {
        guard let data = configuration.data(using: .utf8), !data.isEmpty else {
            throw StoreError.invalidText
        }

        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "\(profileName): \(UUID().uuidString)",
            kSecAttrLabel: "FreeRoute VPN profile: \(profileName)",
            kSecAttrAccessGroup: accessGroup,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data,
            kSecReturnPersistentRef: true
        ]

        var result: CFTypeRef?
        let status = SecItemAdd(attributes as CFDictionary, &result)
        guard status == errSecSuccess, let reference = result as? Data else {
            throw StoreError.status(status == errSecSuccess ? errSecInternalComponent : status)
        }
        return reference
    }

    /// Retrieves the config from Keychain using the persistent reference saved in VPN preferences.
    static func load(reference: Data) -> String? {
        let query: [CFString: Any] = [
            kSecValuePersistentRef: reference,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            NSLog("FreeRoute Keychain lookup failed with OSStatus %d", status)
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(reference: Data) {
        let query: [CFString: Any] = [kSecValuePersistentRef: reference]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            NSLog("FreeRoute Keychain cleanup failed with OSStatus %d", status)
        }
    }
}
