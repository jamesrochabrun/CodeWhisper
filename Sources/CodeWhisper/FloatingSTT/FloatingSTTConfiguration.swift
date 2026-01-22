//
//  FloatingSTTConfiguration.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import Foundation
import CoreGraphics

public struct LLMconfiguration: Codable, Sendable, Equatable {
  
  let model: String
  
  static let standard = LLMconfiguration(model: "gpt-4o-mini")
}

/// Display mode for the floating STT feature
public enum FloatingSTTDisplayMode: String, Codable, Sendable {
  /// Menu bar mode: Shows NSStatusItem, settings via window (default)
  case menuBar
  /// Embedded mode: No menu bar, settings via popover on hover
  case embedded
}

/// Configuration for the floating STT button
public struct FloatingSTTConfiguration: Codable, Sendable, Equatable {
  
  // MARK: - Constants
  
  /// Width of the floating button (horizontal capsule) - fixed size
  public let buttonWidth: CGFloat = 88
  
  /// Height of the floating button (horizontal capsule) - fixed size
  public let buttonHeight: CGFloat = 28
  
  public let llmConfiguration: LLMconfiguration
  
  // MARK: - Properties
  
  /// Last saved position of the button
  public var position: CGPoint
  
  /// Whether to remember the button position between sessions
  public var rememberPosition: Bool
  
  /// Preferred text insertion method
  public var preferredInsertionMethod: TextInsertionMethod
  
  /// Whether to show visual feedback on insertion success/failure
  public var showVisualFeedback: Bool
  
  /// Opacity of the button when idle (0.0 - 1.0)
  public var idleOpacity: CGFloat
  
  /// Whether prompt enhancement is enabled
  public var enhancementEnabled: Bool
  
  /// Custom system prompt for enhancement (nil = use default)
  public var customEnhancementPrompt: String?
  
  /// Display mode (menuBar or embedded)
  public var displayMode: FloatingSTTDisplayMode
  
  // MARK: - Computed Properties
  
  /// Returns the enhancement prompt to use (custom or default)
  public var enhancementPrompt: String {
    if let custom = customEnhancementPrompt, !custom.isEmpty {
      return custom
    }
    return PromptEnhancer.defaultSystemPrompt
  }
  
  /// Size as CGSize for convenience
  public var buttonSize: CGSize {
    CGSize(width: buttonWidth, height: buttonHeight)
  }
  
  // MARK: - Initialization
  
  public init(
    position: CGPoint = CGPoint(x: 20, y: 100),
    rememberPosition: Bool = true,
    preferredInsertionMethod: TextInsertionMethod = .accessibilityAPI,
    showVisualFeedback: Bool = true,
    idleOpacity: CGFloat = 1.0,
    enhancementEnabled: Bool = false,
    customEnhancementPrompt: String? = nil,
    displayMode: FloatingSTTDisplayMode = .menuBar,
    llmConfiguration: LLMconfiguration
  ) {
    self.position = position
    self.rememberPosition = rememberPosition
    self.preferredInsertionMethod = preferredInsertionMethod
    self.showVisualFeedback = showVisualFeedback
    self.idleOpacity = idleOpacity
    self.enhancementEnabled = enhancementEnabled
    self.customEnhancementPrompt = customEnhancementPrompt
    self.displayMode = displayMode
    self.llmConfiguration = llmConfiguration
  }
  
  // MARK: - Codable
  
  enum CodingKeys: String, CodingKey {
    case positionX
    case positionY
    case rememberPosition
    case preferredInsertionMethod
    case llmConfiguration
    case showVisualFeedback
    case idleOpacity
    case enhancementEnabled
    case customEnhancementPrompt
    case displayMode
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    // Button size is now hardcoded (buttonWidth/buttonHeight are constants)
    
    let x = try container.decode(CGFloat.self, forKey: .positionX)
    let y = try container.decode(CGFloat.self, forKey: .positionY)
    position = CGPoint(x: x, y: y)
    rememberPosition = try container.decode(Bool.self, forKey: .rememberPosition)
    preferredInsertionMethod = try container.decode(TextInsertionMethod.self, forKey: .preferredInsertionMethod)
    llmConfiguration = try container.decode(LLMconfiguration.self, forKey: .llmConfiguration)
    showVisualFeedback = try container.decode(Bool.self, forKey: .showVisualFeedback)
    idleOpacity = try container.decodeIfPresent(CGFloat.self, forKey: .idleOpacity) ?? 1.0
    enhancementEnabled = try container.decodeIfPresent(Bool.self, forKey: .enhancementEnabled) ?? false
    customEnhancementPrompt = try container.decodeIfPresent(String.self, forKey: .customEnhancementPrompt)
    displayMode = try container.decodeIfPresent(FloatingSTTDisplayMode.self, forKey: .displayMode) ?? .menuBar
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // Button size is hardcoded, no need to persist
    try container.encode(position.x, forKey: .positionX)
    try container.encode(position.y, forKey: .positionY)
    try container.encode(rememberPosition, forKey: .rememberPosition)
    try container.encode(llmConfiguration, forKey: .llmConfiguration)
    try container.encode(preferredInsertionMethod, forKey: .preferredInsertionMethod)
    try container.encode(showVisualFeedback, forKey: .showVisualFeedback)
    try container.encode(idleOpacity, forKey: .idleOpacity)
    try container.encode(enhancementEnabled, forKey: .enhancementEnabled)
    try container.encodeIfPresent(customEnhancementPrompt, forKey: .customEnhancementPrompt)
    try container.encode(displayMode, forKey: .displayMode)
  }
  
  // MARK: - Defaults
  
  /// Default position: horizontally centered, above dock
  @MainActor
  public static var defaultPosition: CGPoint {
    guard let screen = NSScreen.main else {
      return CGPoint(x: 20, y: 100)
    }
    let screenFrame = screen.visibleFrame  // Excludes dock and menu bar
    let buttonWidth: CGFloat = 88
    let x = screenFrame.origin.x + (screenFrame.width - buttonWidth) / 2
    let y = screenFrame.origin.y + 20  // 20pt above dock
    return CGPoint(x: x, y: y)
  }
  
  /// Default configuration
  public static let `default` = FloatingSTTConfiguration(llmConfiguration: .standard)
  
  // MARK: - Persistence
  
  /// UserDefaults key for storing configuration (same as previously used by SettingsManager)
  private static let storageKey = "floating_stt_configuration"
  
  /// Load configuration from UserDefaults
  public static func load() -> FloatingSTTConfiguration {
    guard let data = UserDefaults.standard.data(forKey: storageKey) else {
      return .default
    }
    do {
      return try JSONDecoder().decode(FloatingSTTConfiguration.self, from: data)
    } catch {
      AppLogger.error("Failed to load FloatingSTTConfiguration: \(error)")
      return .default
    }
  }
  
  /// Save configuration to UserDefaults
  public func save() {
    do {
      let data = try JSONEncoder().encode(self)
      UserDefaults.standard.set(data, forKey: Self.storageKey)
    } catch {
      AppLogger.error("Failed to save FloatingSTTConfiguration: \(error)")
    }
  }
}
#endif
