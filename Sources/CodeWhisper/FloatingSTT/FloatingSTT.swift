//
//  FloatingSTT.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import SwiftOpenAI

/// Protocol defining the floating STT interface.
/// Conformers provide a manager instance and implement the core configuration method.
/// All functional methods (show, hide, permissions, etc.) have default implementations.
@MainActor
public protocol FloatingSTTInterface {
  /// The FloatingSTTManager instance
  static var manager: FloatingSTTManager { get }

  /// Core configuration method - conformers must implement this
  /// - Parameters:
  ///   - transcriptionService: The transcription service to use
  ///   - configuration: Optional configuration override
  static func configure(
    transcriptionService: TranscriptionService,
    configuration: FloatingSTTConfiguration?
  )
}

// MARK: - Protocol Extension (Default Implementations)

extension FloatingSTTInterface {

  // MARK: - Configuration Convenience

  /// Configure with just a transcription service (uses current/default configuration)
  public static func configure(transcriptionService: TranscriptionService) {
    configure(transcriptionService: transcriptionService, configuration: nil)
  }

  // MARK: - Visibility

  /// Show the floating STT button
  public static func show() {
    manager.show()
  }

  /// Hide the floating STT button
  public static func hide() {
    manager.hide()
  }

  /// Toggle the floating STT button visibility
  public static func toggle() {
    manager.toggle()
  }

  /// Shutdown the floating STT mode completely (removes menu bar and button)
  public static func shutdown() {
    manager.shutdown()
  }

  /// Whether the floating button is currently visible
  public static var isVisible: Bool {
    manager.isVisible
  }

  // MARK: - Settings

  /// Show the settings window
  public static func showSettings() {
    manager.showSettings()
  }

  // MARK: - Permissions

  /// Whether Accessibility permission is granted
  public static var hasAccessibilityPermission: Bool {
    manager.hasAccessibilityPermission
  }

  /// Request Accessibility permission from the user
  /// - Returns: True if permission was granted
  @discardableResult
  public static func requestAccessibilityPermission() -> Bool {
    manager.requestAccessibilityPermission()
  }

  /// Open System Settings to the Accessibility privacy pane
  public static func openAccessibilitySettings() {
    manager.openAccessibilitySettings()
  }

  /// Refresh the permission state (call after returning from System Settings)
  public static func refreshPermissionState() {
    manager.refreshPermissionState()
  }

  // MARK: - State

  /// Whether a text field is currently focused and can receive inserted text
  public static var canInsertText: Bool {
    manager.canInsertText
  }

  /// The current configuration
  public static var configuration: FloatingSTTConfiguration {
    get { manager.configuration }
    set { manager.configuration = newValue }
  }
}

// MARK: - Default Implementation

/// Default implementation of FloatingSTTInterface.
///
/// Provides system-wide voice-to-text input via a floating button:
/// - Tap to record speech, tap again to transcribe
/// - Automatically inserts transcribed text into the focused text field
/// - Works in any application
///
/// ## Usage
///
/// ### Simple (with API key):
/// ```swift
/// FloatingSTT.configure(apiKey: "sk-...")
/// FloatingSTT.show()
/// ```
///
/// ### Embedded mode (no menu bar):
/// ```swift
/// FloatingSTT.configureEmbedded(apiKey: "sk-...")
/// FloatingSTT.show()
/// ```
///
/// ### Custom transcription service:
/// ```swift
/// FloatingSTT.configure(transcriptionService: myCustomService)
/// FloatingSTT.show()
/// ```
///
/// ### Handle events:
/// ```swift
/// FloatingSTT.manager.onTextInserted = { text, result in
///     print("Inserted: \(text)")
/// }
/// ```
public enum FloatingSTT: FloatingSTTInterface {

  /// The shared FloatingSTTManager instance
  public static let manager = FloatingSTTManager()

  // MARK: - Core Configuration (Protocol Requirement)

  /// Configure with a transcription service and optional configuration
  /// - Parameters:
  ///   - transcriptionService: The transcription service to use
  ///   - configuration: Optional configuration override
  public static func configure(
    transcriptionService: TranscriptionService,
    configuration: FloatingSTTConfiguration?
  ) {
    if let config = configuration {
      manager.configuration = config
    }
    manager.configure(transcriptionService: transcriptionService)
  }

  // MARK: - OpenAI Convenience Methods

  /// Configure with an OpenAI API key
  /// - Parameter apiKey: The OpenAI API key for Whisper transcription
  public static func configure(apiKey: String) {
    let service = OpenAIServiceFactory.service(apiKey: apiKey)
    let adapter = OpenAITranscriptionAdapter(service: service)
    configure(transcriptionService: adapter, configuration: nil)
  }

  /// Configure with a custom OpenAI service
  /// - Parameter service: The OpenAI service for Whisper transcription
  public static func configure(service: OpenAIService) {
    let adapter = OpenAITranscriptionAdapter(service: service)
    configure(transcriptionService: adapter, configuration: nil)
  }

  /// Configure with an API key and display mode
  /// - Parameters:
  ///   - apiKey: The OpenAI API key for Whisper transcription
  ///   - embedded: If true, uses embedded mode (no menu bar)
  public static func configure(apiKey: String, embedded: Bool) {
    if embedded {
      configureEmbedded(apiKey: apiKey)
    } else {
      configure(apiKey: apiKey)
    }
  }

  /// Configure with a custom OpenAI service and display mode
  /// - Parameters:
  ///   - service: The OpenAI service for Whisper transcription
  ///   - embedded: If true, uses embedded mode (no menu bar)
  public static func configure(service: OpenAIService, embedded: Bool) {
    if embedded {
      configureEmbedded(service: service)
    } else {
      configure(service: service)
    }
  }

  // MARK: - Embedded Mode

  /// Configure for embedded mode with an API key
  ///
  /// Embedded mode is designed for use within a host Mac app:
  /// - No menu bar item is created
  /// - Settings are accessed via hover button next to main button
  ///
  /// - Parameter apiKey: The OpenAI API key for Whisper transcription
  public static func configureEmbedded(apiKey: String) {
    var config = FloatingSTTConfiguration.load()
    config.displayMode = .embedded
    let service = OpenAIServiceFactory.service(apiKey: apiKey)
    let adapter = OpenAITranscriptionAdapter(service: service)
    configure(transcriptionService: adapter, configuration: config)
  }

  /// Configure for embedded mode with a custom OpenAI service
  ///
  /// Embedded mode is designed for use within a host Mac app:
  /// - No menu bar item is created
  /// - Settings are accessed via hover button next to main button
  ///
  /// - Parameter service: The OpenAI service for Whisper transcription
  public static func configureEmbedded(service: OpenAIService) {
    var config = FloatingSTTConfiguration.load()
    config.displayMode = .embedded
    let adapter = OpenAITranscriptionAdapter(service: service)
    configure(transcriptionService: adapter, configuration: config)
  }

  /// Configure for embedded mode with a custom transcription service
  /// - Parameter transcriptionService: The transcription service to use
  public static func configureEmbedded(transcriptionService: TranscriptionService) {
    var config = FloatingSTTConfiguration.load()
    config.displayMode = .embedded
    configure(transcriptionService: transcriptionService, configuration: config)
  }
}
#endif
