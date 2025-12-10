//
//  FloatingSTT.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import SwiftOpenAI

/// Public API for the floating STT (Speech-to-Text) button feature.
///
/// The floating STT button provides system-wide voice-to-text input:
/// - A small floating button that stays on top of all windows
/// - Tap to record speech, tap again to transcribe
/// - Automatically inserts transcribed text into the focused text field
/// - Works in any application
///
/// ## Usage
///
/// ### Simple (recommended):
/// ```swift
/// // Configure with SettingsManager - service is auto-created from API key
/// FloatingSTT.configure(settingsManager: settingsManager)
/// FloatingSTT.show()  // Just works!
/// ```
///
/// ### Advanced (custom service):
/// ```swift
/// // Override with custom OpenAI service if needed
/// FloatingSTT.configure(service: customOpenAIService)
/// FloatingSTT.show()
/// ```
///
/// ### Handle events:
/// ```swift
/// FloatingSTT.shared.onTextInserted = { text, result in
///     print("Inserted: \(text)")
/// }
/// ```
///
/// ## Permissions
///
/// The floating STT feature requires:
/// - **Microphone access**: For recording speech
/// - **Accessibility permission**: For detecting focused text fields and inserting text
///
/// If Accessibility permission is not granted, the feature falls back to clipboard-based
/// text insertion (copies text to clipboard and simulates Cmd+V).
///
public enum FloatingSTT {

    // MARK: - Shared Instance

    /// The shared FloatingSTTManager instance
    @MainActor
    public static let shared = FloatingSTTManager()

    // MARK: - Configuration

    /// Configure with SettingsManager (recommended)
    ///
    /// The OpenAI service will be auto-created from the API key stored in SettingsManager.
    /// - Parameter settingsManager: The settings manager containing the API key
    @MainActor
    public static func configure(settingsManager: SettingsManager) {
        shared.configure(settingsManager: settingsManager)
    }

    /// Configure with a custom OpenAI service (overrides SettingsManager)
    /// - Parameter service: The OpenAI service to use for Whisper transcription
    @MainActor
    public static func configure(service: OpenAIService) {
        shared.configure(service: service)
    }

    /// Configure with a custom configuration and SettingsManager
    /// - Parameters:
    ///   - settingsManager: The settings manager containing the API key
    ///   - configuration: Custom configuration for the floating button
    @MainActor
    public static func configure(settingsManager: SettingsManager, configuration: FloatingSTTConfiguration) {
        shared.configuration = configuration
        shared.configure(settingsManager: settingsManager)
    }

    /// Configure with a custom configuration and OpenAI service
    /// - Parameters:
    ///   - service: The OpenAI service to use for Whisper transcription
    ///   - configuration: Custom configuration for the floating button
    @MainActor
    public static func configure(service: OpenAIService, configuration: FloatingSTTConfiguration) {
        shared.configuration = configuration
        shared.configure(service: service)
    }

    // MARK: - Visibility

    /// Show the floating STT button
    @MainActor
    public static func show() {
        shared.show()
    }
    /// Hide the floating STT button
    @MainActor
    public static func hide() {
        shared.hide()
    }

    /// Toggle the floating STT button visibility
    @MainActor
    public static func toggle() {
        shared.toggle()
    }

    /// Shutdown the floating STT mode completely (removes menu bar and button)
    @MainActor
    public static func shutdown() {
        shared.shutdown()
    }

    /// Whether the floating button is currently visible
    @MainActor
    public static var isVisible: Bool {
        shared.isVisible
    }

    // MARK: - Permissions

    /// Whether Accessibility permission is granted
    @MainActor
    public static var hasAccessibilityPermission: Bool {
        shared.hasAccessibilityPermission
    }

    /// Request Accessibility permission from the user
    /// - Returns: True if permission was granted
    @MainActor
    @discardableResult
    public static func requestAccessibilityPermission() -> Bool {
        shared.requestAccessibilityPermission()
    }

    /// Open System Settings to the Accessibility privacy pane
    @MainActor
    public static func openAccessibilitySettings() {
        shared.openAccessibilitySettings()
    }

    /// Refresh the permission state (call after returning from System Settings)
    @MainActor
    public static func refreshPermissionState() {
        shared.refreshPermissionState()
    }

    // MARK: - State

    /// Whether a text field is currently focused and can receive inserted text
    @MainActor
    public static var canInsertText: Bool {
        shared.canInsertText
    }

    /// The current configuration
    @MainActor
    public static var configuration: FloatingSTTConfiguration {
        get { shared.configuration }
        set { shared.configuration = newValue }
    }
}
#endif
