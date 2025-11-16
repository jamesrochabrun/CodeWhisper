//
//  SettingsManager.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import Foundation
import Observation

@Observable
@MainActor
final class SettingsManager {
  var apiKey: String {
    didSet {
      // Trim whitespace and newlines before saving
      let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmedKey != apiKey {
        apiKey = trimmedKey
      }
      UserDefaults.standard.set(trimmedKey, forKey: "openai_api_key")
    }
  }

  var workingDirectory: String {
    didSet {
      UserDefaults.standard.set(workingDirectory, forKey: "claude_code_working_directory")
      print("SettingsManager: Working directory updated to: \(workingDirectory)")
    }
  }

  var hasValidAPIKey: Bool {
    !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  init() {
    // Load API key
    let savedKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    let trimmedKey = savedKey.trimmingCharacters(in: .whitespacesAndNewlines)

    print("SettingsManager init - Original key length: \(savedKey.count), Trimmed length: \(trimmedKey.count)")
    print("SettingsManager init - Has newlines: \(savedKey.contains("\n"))")

    // If the key had whitespace/newlines, save the trimmed version
    if savedKey != trimmedKey {
      print("SettingsManager init - Trimming and saving cleaned key")
      UserDefaults.standard.set(trimmedKey, forKey: "openai_api_key")
    }

    self.apiKey = trimmedKey

    // Load working directory or use Documents folder as default
    let defaultDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
    self.workingDirectory = UserDefaults.standard.string(forKey: "claude_code_working_directory") ?? defaultDir

    print("SettingsManager init - Working directory: \(workingDirectory)")
  }

  func clearAPIKey() {
    apiKey = ""
  }

  func setWorkingDirectory(_ path: String) {
    self.workingDirectory = path
  }
}
