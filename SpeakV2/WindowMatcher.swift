//
//  WindowMatcher.swift
//  SpeakV2
//
//  Smart window matching utility for natural language queries
//

import Foundation
import ScreenCaptureKit

/// Smart window matcher for natural language queries
@MainActor
struct WindowMatcher {

  /// Match windows based on app name or window title
  /// Returns best match or nil if no good match found
  static func findWindow(
    from windows: [SCWindow],
    appName: String? = nil,
    windowTitle: String? = nil
  ) -> SCWindow? {

    // Filter by criteria with fuzzy matching
    let candidates = windows.filter { window in
      var matches = true

      if let targetApp = appName {
        let actualApp = window.owningApplication?.applicationName ?? ""
        matches = matches && fuzzyMatch(actualApp, query: targetApp)
      }

      if let targetTitle = windowTitle {
        let actualTitle = window.title ?? ""
        matches = matches && fuzzyMatch(actualTitle, query: targetTitle)
      }

      return matches
    }

    // Return first match (windows already sorted by app name)
    return candidates.first
  }

  /// Fuzzy matching with case-insensitive partial matching
  private static func fuzzyMatch(_ text: String, query: String) -> Bool {
    let normalizedText = text.lowercased()
    let normalizedQuery = query.lowercased()

    // Direct contains
    if normalizedText.contains(normalizedQuery) {
      return true
    }

    // Check common synonyms
    let synonyms = getSynonyms(for: normalizedQuery)
    return synonyms.contains { normalizedText.contains($0) }
  }

  /// Return synonyms for common app names
  private static func getSynonyms(for query: String) -> [String] {
    let synonymMap: [String: [String]] = [
      "terminal": ["terminal", "iterm", "warp", "alacritty", "kitty"],
      "browser": ["safari", "chrome", "firefox", "brave", "arc", "edge"],
      "code": ["vscode", "xcode", "code", "cursor", "sublime", "nova"],
      "editor": ["vscode", "xcode", "sublime", "textmate", "nova", "code", "cursor"],
      "notes": ["notes", "notion", "obsidian", "bear", "evernote"],
      "chat": ["slack", "discord", "teams", "messages", "telegram", "whatsapp"],
      "music": ["music", "spotify", "youtube music", "apple music"],
      "mail": ["mail", "outlook", "thunderbird", "spark"],
      "finder": ["finder"],
      "preview": ["preview"],
      "photos": ["photos"],
    ]

    return synonymMap[query.lowercased()] ?? [query.lowercased()]
  }
}
