//
//  FloatingSTTManager.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import Observation
import SwiftOpenAI

/// Orchestrates the floating STT button functionality.
/// Manages recording, transcription, focus detection, and text insertion.
@Observable
@MainActor
public final class FloatingSTTManager {

    // MARK: - Public State

    /// Whether the floating button is currently visible
    public private(set) var isVisible: Bool = false

    /// Whether Accessibility permission is granted
    public private(set) var hasAccessibilityPermission: Bool = false

    /// Whether a text field is currently focused (can insert text)
    public private(set) var canInsertText: Bool = false

    /// The last insertion result
    public private(set) var lastInsertionResult: TextInsertionResult?

    /// The last transcribed text
    public private(set) var lastTranscribedText: String?

    /// Current configuration
    public var configuration: FloatingSTTConfiguration {
        didSet {
            applyConfiguration()
            onConfigurationChanged?(configuration)
        }
    }

    // MARK: - Callbacks

    /// Called when text is successfully transcribed and inserted
    public var onTextInserted: ((String, TextInsertionResult) -> Void)?

    /// Called when an error occurs
    public var onError: ((Error) -> Void)?

    /// Called when configuration changes
    public var onConfigurationChanged: ((FloatingSTTConfiguration) -> Void)?

    // MARK: - Components

    public let sttManager: STTManager
    public let permissionManager: AccessibilityPermissionManager
    private let focusDetector: SystemFocusDetector
    private let textInserter: TextInserter
    private var windowController: FloatingSTTWindowController?

    // MARK: - Private State

    private var focusCheckTimer: Timer?
    private var isConfigured: Bool = false
    private var settingsManager: SettingsManager?
    private var customService: OpenAIService?
    private var menuBarController: FloatingSTTMenuBarController?

    /// Computed service - uses custom if set, otherwise creates from SettingsManager
    private var service: OpenAIService? {
        // Priority 1: Custom injected service
        if let custom = customService {
            return custom
        }
        // Priority 2: Create from SettingsManager API key
        guard let settings = settingsManager, settings.hasValidAPIKey else {
            return nil
        }
        return OpenAIServiceFactory.service(apiKey: settings.apiKey)
    }

    // MARK: - Initialization

    public init(configuration: FloatingSTTConfiguration = .default) {
        self.configuration = configuration
        self.sttManager = STTManager()
        self.permissionManager = AccessibilityPermissionManager()
        self.focusDetector = SystemFocusDetector()
        self.textInserter = TextInserter()

        setup()
    }

    // MARK: - Setup

    private func setup() {
        // Check initial permission state
        hasAccessibilityPermission = permissionManager.checkPermission()

        // Configure text inserter
        textInserter.preferredMethod = configuration.preferredInsertionMethod

        // Set up STT transcription callback
        sttManager.onTranscription = { [weak self] text in
            Task { @MainActor [weak self] in
                await self?.handleTranscription(text)
            }
        }
    }

    // MARK: - Configuration

    /// Configure with SettingsManager (recommended - auto-creates OpenAI service from API key)
    public func configure(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        setupMenuBarIfNeeded()
    }

    /// Configure with a custom OpenAI service (overrides SettingsManager)
    public func configure(service: OpenAIService) {
        self.customService = service
        sttManager.configure(service: service)
        isConfigured = true
        setupMenuBarIfNeeded()
    }

    private func setupMenuBarIfNeeded() {
        guard menuBarController == nil else { return }
        menuBarController = FloatingSTTMenuBarController(floatingManager: self)
    }

    private func applyConfiguration() {
        textInserter.preferredMethod = configuration.preferredInsertionMethod
        windowController?.updateSize(configuration.buttonSize)
    }

    /// The button size as CGSize
    private var buttonSize: CGSize {
        configuration.buttonSize
    }

    // MARK: - Visibility

    /// Show the floating button
    public func show() {
        // Auto-configure STT manager if we have a service (from SettingsManager or custom)
        if !isConfigured, let service = self.service {
            sttManager.configure(service: service)
            isConfigured = true
        }

        guard isConfigured else {
            AppLogger.warning("FloatingSTTManager: Cannot show - no API key available. Call configure(settingsManager:) or configure(service:) first.")
            return
        }

        createWindowControllerIfNeeded()

        let position = configuration.rememberPosition ? configuration.position : FloatingSTTConfiguration.default.position
        windowController?.show(at: position)
        isVisible = true
        menuBarController?.updateMenuState()

        // Start monitoring for focused text fields
        startFocusMonitoring()
    }

    /// Hide the floating button
    public func hide() {
        windowController?.hide()
        isVisible = false
        menuBarController?.updateMenuState()

        // Stop monitoring
        stopFocusMonitoring()

        // Stop any ongoing recording
        sttManager.stop()
    }

    /// Shutdown the floating STT mode completely (removes menu bar and button)
    public func shutdown() {
        hide()
        menuBarController?.remove()
        menuBarController = nil
    }

    /// Toggle visibility
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Recording

    /// Toggle recording (called when button is tapped)
    public func toggleRecording() {
        Task {
            await sttManager.toggleRecording()
        }
    }

    // MARK: - Permission

    /// Request Accessibility permission
    @discardableResult
    public func requestAccessibilityPermission() -> Bool {
        let granted = permissionManager.requestPermission(prompt: true)
        hasAccessibilityPermission = granted
        return granted
    }

    /// Open System Settings to Accessibility pane
    public func openAccessibilitySettings() {
        permissionManager.openSystemSettings()
    }

    /// Refresh permission state (call after returning from settings)
    public func refreshPermissionState() {
        permissionManager.refreshPermissionState()
        hasAccessibilityPermission = permissionManager.isEnabled
    }

    // MARK: - Private Methods

    private func createWindowControllerIfNeeded() {
        guard windowController == nil else { return }

        let controller = FloatingSTTWindowController(buttonSize: buttonSize)

        // Set up position change callback
        controller.onPositionChanged = { [weak self] position in
            guard let self = self, self.configuration.rememberPosition else { return }
            self.configuration.position = position
        }

        // Set up the button view
        controller.setContent { [weak self] in
            guard let self = self else {
                return FloatingSTTButtonView(
                    sttManager: STTManager(),
                    buttonSize: CGSize(width: 72, height: 44),
                    canInsertText: false,
                    onTap: {}
                )
            }

            return FloatingSTTButtonView(
                sttManager: self.sttManager,
                buttonSize: self.buttonSize,
                canInsertText: self.canInsertText,
                onTap: { [weak self] in
                    self?.toggleRecording()
                },
                onLongPress: { [weak self] in
                    // Could show settings or context menu
                    self?.openAccessibilitySettings()
                }
            )
        }

        self.windowController = controller
    }

    private func handleTranscription(_ text: String) async {
        lastTranscribedText = text

        // Detect focused text element
        let focusedElement = focusDetector.getFocusedTextElement()

        // Insert text
        let result: TextInsertionResult
        if hasAccessibilityPermission, let element = focusedElement {
            result = await textInserter.insertText(text, into: element.axElement)
        } else {
            // Fall back to clipboard paste
            result = await textInserter.insertText(text, into: nil)
        }

        lastInsertionResult = result

        // Notify
        switch result {
        case .success:
            onTextInserted?(text, result)
        case .failure(let error):
            onError?(error)
        }
    }

    // MARK: - Focus Monitoring

    private func startFocusMonitoring() {
        // Check immediately
        updateFocusState()

        // Then periodically check (every 0.5 seconds)
        focusCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateFocusState()
            }
        }
    }

    private func stopFocusMonitoring() {
        focusCheckTimer?.invalidate()
        focusCheckTimer = nil
    }

    private func updateFocusState() {
        canInsertText = focusDetector.isTextFieldFocused()
    }
}
#endif
