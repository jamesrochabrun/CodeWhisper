//
//  CodeWhisperButton.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/29/25.
//

import Combine
import SwiftUI

/// A standalone button for voice mode with tap and long-press actions.
/// - Tap: Starts the currently selected voice mode (from settings)
/// - Long-press: Opens CodeWhisper settings
public struct CodeWhisperButton: View {

  // MARK: - Voice Phase (for STT+TTS)

  private enum VoicePhase {
    case idle       // Not recording
    case stt        // Recording/transcribing
    case waiting    // Waiting for assistant response
    case tts        // Speaking assistant response
  }

  // MARK: - Dependencies

  private let chatInterface: VoiceModeChatInterface?
  private let executor: ClaudeCodeExecutor?

  // MARK: - Configuration

  private let configuration: CodeWhisperConfiguration
  private let onTranscription: ((String) -> Void)?
  private let onDismiss: (() -> Void)?

  // MARK: - State

  @State private var showingSettings = false
  @State private var showingVoiceMode = false
  @State private var showingRealtimeSheet = false
  @Binding private var isRealtimeSessionActive: Bool
  @State private var currentPhase: VoicePhase = .idle
  @State private var transcribedText: String = ""
  @State private var lastSpokenMessageId: UUID?
  @State private var waitingForResponse = false
  @State private var sttStopAction: (() -> Void)?
  @State private var cancellables = Set<AnyCancellable>()

  // Settings and service managers
  @State private var settingsManager = SettingsManager()
  @State private var serviceManager = OpenAIServiceManager()
  @State private var mcpManager = MCPServerManager()
  @State private var ttsSpeaker = TTSSpeaker()

  // MARK: - Initialization

  /// Creates a CodeWhisperButton with a VoiceModeChatInterface for message observation
  /// - Parameters:
  ///   - chatInterface: Interface for sending messages and receiving assistant responses
  ///   - configuration: Configuration specifying available voice modes
  ///   - isRealtimeSessionActive: Binding to track whether realtime mode is active
  ///   - onTranscription: Optional callback when transcription is complete
  ///   - onDismiss: Optional callback when voice mode is dismissed
  public init(
    chatInterface: VoiceModeChatInterface?,
    configuration: CodeWhisperConfiguration = .all,
    isRealtimeSessionActive: Binding<Bool> = .constant(false),
    onTranscription: ((String) -> Void)? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.chatInterface = chatInterface
    self.executor = nil
    self.configuration = configuration
    self._isRealtimeSessionActive = isRealtimeSessionActive
    self.onTranscription = onTranscription
    self.onDismiss = onDismiss
  }

  /// Creates a CodeWhisperButton with a ClaudeCodeExecutor for realtime mode
  /// - Parameters:
  ///   - executor: Executor for realtime voice mode
  ///   - configuration: Configuration specifying available voice modes
  ///   - isRealtimeSessionActive: Binding to track whether realtime mode is active
  ///   - onTranscription: Optional callback when transcription is complete
  ///   - onDismiss: Optional callback when voice mode is dismissed
  public init(
    executor: ClaudeCodeExecutor?,
    configuration: CodeWhisperConfiguration = .all,
    isRealtimeSessionActive: Binding<Bool> = .constant(false),
    onTranscription: ((String) -> Void)? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.chatInterface = nil
    self.executor = executor
    self.configuration = configuration
    self._isRealtimeSessionActive = isRealtimeSessionActive
    self.onTranscription = onTranscription
    self.onDismiss = onDismiss
  }

  /// Creates a CodeWhisperButton with both interfaces
  /// - Parameters:
  ///   - chatInterface: Interface for sending messages and receiving assistant responses
  ///   - executor: Executor for realtime voice mode
  ///   - configuration: Configuration specifying available voice modes
  ///   - isRealtimeSessionActive: Binding to track whether realtime mode is active
  ///   - onTranscription: Optional callback when transcription is complete
  ///   - onDismiss: Optional callback when voice mode is dismissed
  public init(
    chatInterface: VoiceModeChatInterface?,
    executor: ClaudeCodeExecutor?,
    configuration: CodeWhisperConfiguration = .all,
    isRealtimeSessionActive: Binding<Bool> = .constant(false),
    onTranscription: ((String) -> Void)? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.chatInterface = chatInterface
    self.executor = executor
    self.configuration = configuration
    self._isRealtimeSessionActive = isRealtimeSessionActive
    self.onTranscription = onTranscription
    self.onDismiss = onDismiss
  }

  // MARK: - Body

  public var body: some View {
    HStack(spacing: 0) {
      if showingVoiceMode {
        voiceModeContent
          .transition(.opacity)
      }
      buttonContent
    }
    .background {
      Capsule()
        .fill(.ultraThinMaterial)
    }
    .clipShape(Capsule())
    .animation(.easeInOut, value: showingVoiceMode)
    .overlay {
      // Hidden button for keyboard shortcut
      keyboardShortcutButton
        .allowsHitTesting(false)
    }
    .onAppear(perform: handleOnAppear)
    .onChange(of: settingsManager.apiKey, handleAPIKeyChange)
    .onChange(of: settingsManager.ttsConfiguration, handleTTSConfigChange)
    .onChange(of: ttsSpeaker.state, handleTTSStateChange)
    .sheet(isPresented: $showingSettings) {
      CodeWhisperSettingsSheet(configuration: configuration)
        .environment(settingsManager)
        .environment(mcpManager)
    }
    .sheet(isPresented: $showingRealtimeSheet) {
      realtimeModeView
        .frame(minWidth: 600, minHeight: 400)
    }
    .onChange(of: showingRealtimeSheet) { _, newValue in
      isRealtimeSessionActive = newValue
    }
  }

  // MARK: - Keyboard Shortcut

  @ViewBuilder
  private var keyboardShortcutButton: some View {
    let shortcut = settingsManager.recordingShortcut
    Button(action: handleKeyboardShortcut) {
      EmptyView()
    }
    .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.eventModifiers)
    .opacity(0)
    .frame(width: 0, height: 0)
  }

  private func handleKeyboardShortcut() {
    switch currentPhase {
    case .idle:
      if settingsManager.hasValidAPIKey {
        startVoiceMode()
      } else {
        showingSettings = true
      }
    case .stt:
      sttStopAction?()
    case .waiting:
      // Do nothing while waiting for response
      break
    case .tts:
      ttsSpeaker.stop()
      resetToIdle()
    }
  }

  // MARK: - Button Content

  @ViewBuilder
  private var buttonContent: some View {
    switch currentPhase {
    case .idle:
      idleButton
    case .stt:
      recordingButton
    case .waiting:
      // Hidden while waiting for response
      EmptyView()
    case .tts:
      ttsView
    }
  }

  private var idleButton: some View {
    Image(systemName: "waveform.circle.fill")
      .font(.title2)
      .foregroundColor(settingsManager.hasValidAPIKey ? .primary : .secondary)
      .padding(8)
      .contentShape(Rectangle())
      .onTapGesture {
        if settingsManager.hasValidAPIKey {
          startVoiceMode()
        } else {
          showingSettings = true
        }
      }
      .onLongPressGesture(minimumDuration: 0.5) {
        showingSettings = true
      }
      .help(settingsManager.hasValidAPIKey ? "Tap: Voice Mode | Hold: Settings" : "Configure API key")
  }

  private var recordingButton: some View {
    Image(systemName: "mic.circle.fill")
      .font(.title2)
      .foregroundColor(.primary)
      .padding(8)
      .contentShape(Rectangle())
      .onTapGesture {
        sttStopAction?()
      }
      .help("Tap to stop recording")
  }

  private var ttsView: some View {
    HStack(spacing: 8) {
      Button {
        ttsSpeaker.stop()
        resetToIdle()
      } label: {
        ZStack {
          Circle()
            .fill(Color.green.opacity(0.8))
            .frame(width: 28, height: 28)
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 10, height: 10)
        }
      }
      .buttonStyle(.plain)
      .help("Stop speaking")

      WaveformBarsView(
        waveformLevels: deriveTTSWaveform(ttsSpeaker.audioLevel),
        barColor: .teal,
        isActive: true
      )
      .frame(height: 26)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
  }

  // MARK: - Voice Mode Content

  @ViewBuilder
  private var voiceModeContent: some View {
    let selectedMode = settingsManager.selectedVoiceMode

    switch selectedMode {
    case .stt:
      sttModeView
    case .sttWithTTS:
      sttWithTTSModeView
    case .realtime:
      // Realtime mode is shown as a sheet, not inline
      EmptyView()
    }
  }

  private var sttModeView: some View {
    InlineVoiceModeView(
      mode: .stt,
      height: 42,
      transcribedText: $transcribedText,
      stopRecordingAction: $sttStopAction,
      onTranscription: handleSTTTranscription,
      onDismiss: handleSTTDismiss,
      ttsSpeaker: ttsSpeaker
    )
    .environment(settingsManager)
    .environment(serviceManager)
  }

  private var sttWithTTSModeView: some View {
    InlineVoiceModeView(
      mode: .stt,  // Use STT mode, TTS is handled separately
      height: 42,
      transcribedText: $transcribedText,
      stopRecordingAction: $sttStopAction,
      onTranscription: handleSTTWithTTSTranscription,
      onDismiss: handleSTTWithTTSDismiss,
      ttsSpeaker: ttsSpeaker
    )
    .environment(settingsManager)
    .environment(serviceManager)
  }

  private var realtimeModeView: some View {
    VoiceModeView(
      presentationMode: .presented,
      executor: executor
    )
    .environment(settingsManager)
    .environment(serviceManager)
    .environment(mcpManager)
  }

  // MARK: - Lifecycle Handlers

  private func handleOnAppear() {
    serviceManager.updateService(apiKey: settingsManager.apiKey)
    ttsSpeaker.configuration = settingsManager.ttsConfiguration
    if let service = serviceManager.service {
      ttsSpeaker.configure(service: service)
    }
    setupMessageSubscription()
  }

  private func handleAPIKeyChange(_: String, _ newValue: String) {
    serviceManager.updateService(apiKey: newValue)
    if let service = serviceManager.service {
      ttsSpeaker.configure(service: service)
    }
  }

  private func handleTTSConfigChange(_: TTSConfiguration, _ newConfig: TTSConfiguration) {
    ttsSpeaker.configuration = newConfig
  }

  private func handleTTSStateChange(_: TTSSpeakingState, _ newState: TTSSpeakingState) {
    if currentPhase == .tts && !newState.isSpeaking {
      resetToIdle()
    }
  }

  // MARK: - Message Subscription

  private func setupMessageSubscription() {
    guard let chatInterface = chatInterface else { return }

    chatInterface.assistantMessageCompletedPublisher
      .receive(on: DispatchQueue.main)
      .sink { [self] message in
        handleAssistantMessageCompleted(message)
      }
      .store(in: &cancellables)
  }

  private func handleAssistantMessageCompleted(_ message: VoiceModeMessage) {
    guard waitingForResponse,
          message.id != lastSpokenMessageId,
          message.role == .assistant,
          !message.content.isEmpty else {
      return
    }

    lastSpokenMessageId = message.id
    waitingForResponse = false
    showingVoiceMode = false
    currentPhase = .tts
    ttsSpeaker.speak(text: message.content)
  }

  // MARK: - Voice Mode Actions

  private func startVoiceMode() {
    var mode = settingsManager.selectedVoiceMode

    // Fallback to first available if current selection isn't available
    if !configuration.availableVoiceModes.contains(mode) {
      mode = configuration.defaultVoiceMode
      settingsManager.selectedVoiceMode = mode
    }

    if mode == .realtime {
      // Show realtime mode as a sheet
      showingRealtimeSheet = true
    } else {
      // Show inline voice mode for STT and STT+TTS
      currentPhase = .stt
      showingVoiceMode = true
    }
  }

  private func handleSTTTranscription(_ text: String) {
    onTranscription?(text)
    chatInterface?.sendVoiceMessage(text)
  }

  private func handleSTTDismiss() {
    resetToIdle()
    onDismiss?()
  }

  private func handleSTTWithTTSTranscription(_ text: String) {
    waitingForResponse = true
    onTranscription?(text)
    chatInterface?.sendVoiceMessage(text)
  }

  private func handleSTTWithTTSDismiss() {
    // Transition to waiting phase if in sttWithTTS mode
    if settingsManager.selectedVoiceMode == .sttWithTTS && waitingForResponse {
      showingVoiceMode = false
      currentPhase = .waiting
    } else {
      resetToIdle()
      onDismiss?()
    }
  }

  private func handleRealtimeDismiss() {
    resetToIdle()
    onDismiss?()
  }

  private func resetToIdle() {
    currentPhase = .idle
    showingVoiceMode = false
    waitingForResponse = false
    transcribedText = ""
  }

  // MARK: - Helpers

  private func deriveTTSWaveform(_ audioLevel: Float) -> [Float] {
    (0..<8).map { index in
      let variation = Float(sin(Double(index) * 0.6 + Double(audioLevel) * 8) * 0.3 + 0.7)
      return min(1.0, audioLevel * variation)
    }
  }
}

// MARK: - Preview

#Preview {
  CodeWhisperButton(chatInterface: nil)
    .frame(height: 50)
    .padding()
}



// Ok now lets animate button mic with voice ts
// tts ans stt we should show the stt view when is speaking.
// finally very important is to handle correctly the configurtaion
// lastly we should cancel previous speak if there is a new one
