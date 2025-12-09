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
  private static let ttsConfigKey = "tts_configuration"
  private static let voiceModeKey = "code_whisper_voice_mode"
  private static let realtimeLanguageKey = "realtime_transcription_language"

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

  /// TTS configuration
  public var ttsConfiguration: TTSConfiguration {
    didSet {
      saveTTSConfiguration()
    }
  }

  /// Selected voice mode
  public var selectedVoiceMode: VoiceMode {
    didSet {
      saveVoiceMode()
    }
  }

  /// Selected transcription language for Realtime API (ISO-639-1 code)
  public var realtimeLanguage: RealtimeLanguage {
    didSet {
      saveRealtimeLanguage()
    }
  }

  // MARK: - TTS Convenience Properties

  /// Current TTS provider
  public var ttsProvider: TTSProvider {
    get { ttsConfiguration.provider }
    set {
      ttsConfiguration.provider = newValue
    }
  }

  /// Current OpenAI TTS voice
  public var openAITTSVoice: OpenAITTSVoice {
    get { ttsConfiguration.openAIVoice }
    set {
      ttsConfiguration.openAIVoice = newValue
    }
  }

  /// Current OpenAI TTS model
  public var openAITTSModel: OpenAITTSModel {
    get { ttsConfiguration.openAIModel }
    set {
      ttsConfiguration.openAIModel = newValue
    }
  }

  /// Returns the ISO-639-1 language code for Realtime API, or nil for auto-detect
  public var realtimeLanguageCode: String? {
    realtimeLanguage.code
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

    // Load TTS configuration or use default
    self.ttsConfiguration = Self.loadTTSConfiguration()

    // Load selected voice mode or use default (.stt)
    self.selectedVoiceMode = Self.loadVoiceMode()

    // Load realtime language or use default (.auto)
    self.realtimeLanguage = Self.loadRealtimeLanguage()
  }

  // MARK: - TTS Configuration Persistence

  private func saveTTSConfiguration() {
    do {
      let data = try JSONEncoder().encode(ttsConfiguration)
      UserDefaults.standard.set(data, forKey: Self.ttsConfigKey)
    } catch {
      AppLogger.error("Failed to save TTS configuration: \(error)")
    }
  }

  private static func loadTTSConfiguration() -> TTSConfiguration {
    guard let data = UserDefaults.standard.data(forKey: ttsConfigKey) else {
      return .default
    }
    do {
      return try JSONDecoder().decode(TTSConfiguration.self, from: data)
    } catch {
      AppLogger.error("Failed to load TTS configuration: \(error)")
      return .default
    }
  }

  // MARK: - Voice Mode Persistence

  private func saveVoiceMode() {
    UserDefaults.standard.set(selectedVoiceMode.rawValue, forKey: Self.voiceModeKey)
  }

  private static func loadVoiceMode() -> VoiceMode {
    guard let rawValue = UserDefaults.standard.string(forKey: voiceModeKey),
          let mode = VoiceMode(rawValue: rawValue) else {
      return .stt  // Default voice mode
    }
    return mode
  }

  // MARK: - Realtime Language Persistence

  private func saveRealtimeLanguage() {
    UserDefaults.standard.set(realtimeLanguage.rawValue, forKey: Self.realtimeLanguageKey)
  }

  private static func loadRealtimeLanguage() -> RealtimeLanguage {
    guard let rawValue = UserDefaults.standard.string(forKey: realtimeLanguageKey) else {
      return .auto  // Default to auto-detect
    }
    return RealtimeLanguage(rawValue: rawValue) ?? .custom(rawValue)
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
