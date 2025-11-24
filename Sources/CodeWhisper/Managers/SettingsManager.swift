//
//  SettingsManager.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import Foundation
import Observation
import os

@Observable
@MainActor
public final class SettingsManager {

  private static let apiKeyEnvVar = "OPENAI_API_KEY"
  private static let keychainKey = "openai_api_key"

  /// The current API key - either from environment variable or stored in Keychain
  public var apiKey: String {
    didSet {
      // Only save to Keychain if it's not coming from environment variable
      if !isUsingEnvironmentVariable {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey != apiKey {
          apiKey = trimmedKey
        }
        KeychainManager.shared.save(trimmedKey, forKey: Self.keychainKey)
      }
    }
  }

  /// Indicates whether the API key is coming from an environment variable
  public var isUsingEnvironmentVariable: Bool {
    ProcessInfo.processInfo.environment[Self.apiKeyEnvVar] != nil
  }

  /// The source of the current API key for display purposes
  public var apiKeySource: String {
    isUsingEnvironmentVariable ? "Environment Variable (\(Self.apiKeyEnvVar))" : "Keychain (Secure Storage)"
  }

  public var workingDirectory: String {
    didSet {
      UserDefaults.standard.set(workingDirectory, forKey: "claude_code_working_directory")
    }
  }

  public var bypassPermissions: Bool {
    didSet {
      UserDefaults.standard.set(bypassPermissions, forKey: "claude_code_bypass_permissions")
    }
  }

  public var hasValidAPIKey: Bool {
    !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public init() {
    // Priority 1: Check for environment variable
    if let envKey = ProcessInfo.processInfo.environment[Self.apiKeyEnvVar], !envKey.isEmpty {
      let trimmedKey = envKey.trimmingCharacters(in: .whitespacesAndNewlines)
      self.apiKey = trimmedKey
      AppLogger.info("Using API key from environment variable")
    }
    // Priority 2: Check Keychain
    else if let keychainKey = KeychainManager.shared.retrieve(forKey: Self.keychainKey), !keychainKey.isEmpty {
      self.apiKey = keychainKey
      AppLogger.info("Using API key from Keychain")
    }
    // No key found
    else {
      self.apiKey = ""
      AppLogger.warning("No API key found")
    }

    // Load working directory or use Documents folder as default
    let defaultDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
    self.workingDirectory = UserDefaults.standard.string(forKey: "claude_code_working_directory") ?? defaultDir

    // Load bypass permissions setting (default: false)
    self.bypassPermissions = UserDefaults.standard.bool(forKey: "claude_code_bypass_permissions")
  }

  public func clearAPIKey() {
    // Only clear if not using environment variable
    if !isUsingEnvironmentVariable {
      KeychainManager.shared.delete(forKey: Self.keychainKey)
      apiKey = ""
    }
  }

  public func setWorkingDirectory(_ path: String) {
    self.workingDirectory = path
  }
}
