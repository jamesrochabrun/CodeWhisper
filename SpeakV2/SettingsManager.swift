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
  
  var hasValidAPIKey: Bool {
    !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  init() {
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
  }
  
  func clearAPIKey() {
    apiKey = ""
  }
}
