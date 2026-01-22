//
//  FloatingSTTManager.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import Observation

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
  
  /// Current configuration (auto-persisted to UserDefaults)
  public var configuration: FloatingSTTConfiguration {
    didSet {
      configuration.save()
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
  private let promptEnhancer: PromptEnhancer
  private var windowController: FloatingSTTWindowController?
  
  // MARK: - Private State

  private var focusCheckTimer: Timer?
  private var isConfigured: Bool = false
  private var menuBarController: FloatingSTTMenuBarController?
  private var settingsWindowController: FloatingSTTSettingsWindowController?
  
  // MARK: - Initialization
  
  /// Initialize with optional configuration override. If nil, loads from UserDefaults.
  public init(configuration: FloatingSTTConfiguration? = nil) {
    self.configuration = configuration ?? FloatingSTTConfiguration.load()
    self.sttManager = STTManager()
    self.permissionManager = AccessibilityPermissionManager()
    self.focusDetector = SystemFocusDetector()
    self.textInserter = TextInserter()
    self.promptEnhancer = PromptEnhancer()
    
    setup()
  }
  
  // MARK: - Setup
  
  private func setup() {
    // Check initial permission state
    hasAccessibilityPermission = permissionManager.checkPermission()
    
    // Configure text inserter
    textInserter.preferredMethod = configuration.preferredInsertionMethod
    
    let model = configuration.llmConfiguration.model
    // Set up STT transcription callback
    sttManager.onTranscription = { [weak self] text in
      Task { @MainActor [weak self] in
        await self?.handleTranscription(text, model: model)
      }
    }
  }
  
  // MARK: - Configuration

  /// Configure with a transcription service
  public func configure(transcriptionService: TranscriptionService) {
    AppLogger.info("[FloatingSTTManager] configure(transcriptionService:) called")
    sttManager.configure(transcriptionService: transcriptionService)
    isConfigured = true
    setupMenuBarIfNeeded()
    AppLogger.info("[FloatingSTTManager] Configuration complete (transcriptionService only)")
  }

  public func configure(transcriptionService: TranscriptionService, chatService: ChatService) {
    sttManager.configure(transcriptionService: transcriptionService)
    promptEnhancer.configure(chatService: chatService)
    isConfigured = true
    setupMenuBarIfNeeded()
    AppLogger.info("[FloatingSTTManager] Configuration complete (transcriptionService + chatService)")
  }
    
  private func setupMenuBarIfNeeded() {
    // Only create menu bar for menuBar mode
    guard configuration.displayMode == .menuBar else { return }
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
    guard isConfigured else {
      AppLogger.warning("FloatingSTTManager: Cannot show - not configured. Call configure(transcriptionService:) first.")
      return
    }

    createWindowControllerIfNeeded()

    // Always use fixed centered position above dock
    let position = calculateFixedPosition()
    windowController?.show(at: position)
    isVisible = true
    menuBarController?.updateMenuState()

    // Start monitoring for focused text fields
    startFocusMonitoring()
  }

  /// Calculate the fixed position: horizontally centered, above dock
  private func calculateFixedPosition() -> CGPoint {
    guard let screen = NSScreen.main else {
      return CGPoint(x: 20, y: 100)
    }
    let screenFrame = screen.visibleFrame  // Excludes dock and menu bar
    let buttonWidth: CGFloat = 88  // Use expanded width for positioning
    let x = screenFrame.origin.x + (screenFrame.width - buttonWidth) / 2
    let y = screenFrame.origin.y + 20  // 20pt above dock
    return CGPoint(x: x, y: y)
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
  
  // MARK: - Settings
  
  /// Show the settings window
  /// Note: In embedded mode, settings are shown via popover from the floating button
  public func showSettings() {
    // In embedded mode, settings are accessed via hover popover, not a window
    guard configuration.displayMode == .menuBar else { return }
    
    if settingsWindowController == nil {
      settingsWindowController = FloatingSTTSettingsWindowController()
    }
    settingsWindowController?.showSettings(manager: self)
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
    
    let isEmbedded = configuration.displayMode == .embedded
    
    // Embedded mode uses same size as menu bar mode (right-click for settings)
    let panelSize = buttonSize
    
    let controller = FloatingSTTWindowController(buttonSize: panelSize)

    // Position is now fixed - no position change callback needed

    // Set up the button view based on mode
    if isEmbedded {
      controller.setContent { [weak self] in
        guard let self = self else {
          return FloatingSTTEmbeddedContainerView(
            sttManager: STTManager(),
            floatingManager: FloatingSTTManager(),
            buttonSize: CGSize(width: 88, height: 28),
            canInsertText: false,
            onTap: {},
            onLongPress: nil
          )
        }
        
        return FloatingSTTEmbeddedContainerView(
          sttManager: self.sttManager,
          floatingManager: self,
          buttonSize: self.buttonSize,
          canInsertText: self.canInsertText,
          onTap: { [weak self] in
            self?.toggleRecording()
          },
          onLongPress: { [weak self] in
            self?.openAccessibilitySettings()
          }
        )
      }
    } else {
      // Menu bar mode - standard button view
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
    }
    
    self.windowController = controller
  }
  
  private func handleTranscription(_ text: String, model: String) async {
    lastTranscribedText = text
    
    // Enhance text if enabled (stays in transcribing state during enhancement)
    var finalText = text
    if configuration.enhancementEnabled {
      do {
        finalText = try await promptEnhancer.enhance(
          text: text, model: model,
          systemPrompt: configuration.enhancementPrompt
        )
        AppLogger.info("[PromptEnhancer] '\(text)' → '\(finalText)'")
      } catch {
        // Enhancement failed, use raw text
        AppLogger.warning("[PromptEnhancer] Enhancement failed: \(error.localizedDescription)")
      }
    }
    
    // Detect focused text element
    let focusedElement = focusDetector.getFocusedTextElement()
    
    // Insert text
    let result: TextInsertionResult
    if hasAccessibilityPermission, let element = focusedElement {
      result = await textInserter.insertText(finalText, into: element.axElement)
    } else {
      // Fall back to clipboard paste
      result = await textInserter.insertText(finalText, into: nil)
    }
    
    lastInsertionResult = result
    
    // Notify
    switch result {
    case .success:
      onTextInserted?(finalText, result)
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
