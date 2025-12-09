//
//  KeyboardShortcutConfiguration.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

import SwiftUI

/// Configuration for the keyboard shortcut used to toggle recording
public struct KeyboardShortcutConfiguration: Codable, Equatable {

  // MARK: - Properties

  /// The key character (stored as String for Codable compatibility)
  public var keyCharacter: String

  /// Raw modifier flags (stored as UInt for Codable compatibility)
  public var modifierFlags: UInt

  // MARK: - Computed Properties

  /// SwiftUI KeyEquivalent for use with .keyboardShortcut()
  public var keyEquivalent: KeyEquivalent {
    if keyCharacter == " " {
      return .space
    } else if keyCharacter == "\r" {
      return .return
    } else if let char = keyCharacter.first {
      return KeyEquivalent(char)
    }
    return .space
  }

  /// SwiftUI EventModifiers for use with .keyboardShortcut()
  public var eventModifiers: EventModifiers {
    var modifiers: EventModifiers = []
    let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)

    if flags.contains(.command) {
      modifiers.insert(.command)
    }
    if flags.contains(.shift) {
      modifiers.insert(.shift)
    }
    if flags.contains(.option) {
      modifiers.insert(.option)
    }
    if flags.contains(.control) {
      modifiers.insert(.control)
    }

    return modifiers
  }

  /// Human-readable display string (e.g., "⌘ Space")
  public var displayString: String {
    var parts: [String] = []
    let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)

    if flags.contains(.control) {
      parts.append("⌃")
    }
    if flags.contains(.option) {
      parts.append("⌥")
    }
    if flags.contains(.shift) {
      parts.append("⇧")
    }
    if flags.contains(.command) {
      parts.append("⌘")
    }

    // Add key name
    let keyName: String
    switch keyCharacter {
    case " ":
      keyName = "Space"
    case "\r":
      keyName = "Return"
    case "\t":
      keyName = "Tab"
    default:
      keyName = keyCharacter.uppercased()
    }
    parts.append(keyName)

    return parts.joined(separator: " ")
  }

  // MARK: - Initialization

  public init(keyCharacter: String, modifierFlags: UInt) {
    self.keyCharacter = keyCharacter
    self.modifierFlags = modifierFlags
  }

  /// Initialize from NSEvent (used when recording a shortcut)
  public init?(event: NSEvent) {
    // Must have at least one modifier (Command, Option, or Control)
    let validModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
    guard event.modifierFlags.intersection(validModifiers).isEmpty == false else {
      return nil
    }

    // Get the key character
    guard let characters = event.charactersIgnoringModifiers,
          !characters.isEmpty else {
      return nil
    }

    self.keyCharacter = characters
    // Only store relevant modifier flags
    self.modifierFlags = event.modifierFlags.intersection([.command, .shift, .option, .control]).rawValue
  }

  // MARK: - Default

  /// Default shortcut: Command + . (period)
  public static let `default` = KeyboardShortcutConfiguration(
    keyCharacter: ".",
    modifierFlags: NSEvent.ModifierFlags.command.rawValue
  )

  // MARK: - Validation

  /// Check if this shortcut conflicts with common system shortcuts
  public var isReservedShortcut: Bool {
    let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)

    // Command+Q (Quit) - always reserved
    if flags == .command && keyCharacter.lowercased() == "q" {
      return true
    }

    // Command+H (Hide) - always reserved
    if flags == .command && keyCharacter.lowercased() == "h" {
      return true
    }

    // Command+Tab (App Switcher) - always reserved
    if flags == .command && keyCharacter == "\t" {
      return true
    }

    return false
  }
}
