//
//  KeychainManager.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/20/25.
//

import Foundation
import Security

/// Secure storage manager for sensitive data using the macOS/iOS Keychain
@MainActor
public final class KeychainManager {

    public static let shared = KeychainManager()

    private init() {}

    // MARK: - Keychain Operations

    /// Save a string value to the Keychain
    /// - Parameters:
    ///   - value: The string to save
    ///   - key: The key to identify this value
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("KeychainManager: Failed to convert string to data")
            return false
        }

        // Delete any existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.codewhisper.app",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("KeychainManager: Successfully saved value for key: \(key)")
            return true
        } else {
            print("KeychainManager: Failed to save value for key: \(key), status: \(status)")
            return false
        }
    }

    /// Retrieve a string value from the Keychain
    /// - Parameter key: The key identifying the value
    /// - Returns: The string value, or nil if not found
    public func retrieve(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.codewhisper.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            print("KeychainManager: Successfully retrieved value for key: \(key)")
            return value
        } else if status == errSecItemNotFound {
            print("KeychainManager: No value found for key: \(key)")
            return nil
        } else {
            print("KeychainManager: Failed to retrieve value for key: \(key), status: \(status)")
            return nil
        }
    }

    /// Delete a value from the Keychain
    /// - Parameter key: The key identifying the value to delete
    /// - Returns: True if successful or item didn't exist, false on error
    @discardableResult
    public func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.codewhisper.app"
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            print("KeychainManager: Successfully deleted value for key: \(key)")
            return true
        } else {
            print("KeychainManager: Failed to delete value for key: \(key), status: \(status)")
            return false
        }
    }

    /// Update an existing value in the Keychain
    /// - Parameters:
    ///   - value: The new value
    ///   - key: The key identifying the value to update
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public func update(_ value: String, forKey key: String) -> Bool {
        // For simplicity, we delete and re-add
        return save(value, forKey: key)
    }
}
