//
//  InlineVoiceModeView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/26/25.
//

import SwiftUI

/// A compact inline voice mode view designed to be embedded in chat UIs.
/// Supports four modes:
/// - `.realtime`: Bidirectional voice conversation (default, full functionality)
/// - `.stt`: Speech-to-text only (tap to record, outputs transcription)
/// - `.tts`: Text-to-speech only (parent controls when to speak)
/// - `.sttWithTTS`: Combined STT input + TTS output for voice conversations
public struct InlineVoiceModeView: View {
  
  public enum PresentationMode {
    case standalone
    case presented
  }
  
  // MARK: - Configuration
  
  private let mode: VoiceMode
  private let height: CGFloat
  private let presentationMode: PresentationMode
  private let executor: ClaudeCodeExecutor?
  
  // STT mode bindings and callbacks
  @Binding private var transcribedText: String
  @Binding private var stopRecordingAction: (() -> Void)?
  private let onTranscription: ((String) -> Void)?
  private let onDismiss: (() -> Void)?
  
  // TTS mode - speaker passed in by parent
  private let ttsSpeaker: TTSSpeaker?
  
  // MARK: - Environment
  
  @Environment(OpenAIServiceManager.self) private var serviceManager
  @Environment(SettingsManager.self) private var settingsManager
  @Environment(\.dismiss) private var dismiss
  
  // MARK: - State
  
  // For .realtime mode (existing)
  @State private var conversationManager = ConversationManager()
  
  @State private var isInitializing = true
  @State private var showScreenshotPicker = false
  
  // MARK: - Initializers
  
  /// Initialize for realtime mode (default, full bidirectional voice)
  public init(
    height: CGFloat = 42,
    presentationMode: PresentationMode = .standalone,
    executor: ClaudeCodeExecutor? = nil
  ) {
    self.mode = .realtime
    self.height = height
    self.presentationMode = presentationMode
    self.executor = executor
    self._transcribedText = .constant("")
    self._stopRecordingAction = .constant(nil)
    self.onTranscription = nil
    self.onDismiss = nil
    self.ttsSpeaker = nil
  }
  
  /// Initialize with configurable mode
  /// - Parameters:
  ///   - mode: The voice mode to use (.stt, .tts, .sttWithTTS, or .realtime)
  ///   - height: Height of the view (default 42)
  ///   - presentationMode: Whether view is standalone or presented
  ///   - transcribedText: Binding for STT output (optional)
  ///   - stopRecordingAction: Binding to expose stop action to parent (for STT mode)
  ///   - onTranscription: Callback for STT output (optional)
  ///   - onDismiss: Callback when view should dismiss (after transcription or cancel)
  ///   - ttsSpeaker: TTSSpeaker instance for TTS mode (required for .tts mode)
  ///   - executor: ClaudeCodeExecutor for realtime mode (optional)
  public init(
    mode: VoiceMode,
    height: CGFloat = 42,
    presentationMode: PresentationMode = .standalone,
    transcribedText: Binding<String> = .constant(""),
    stopRecordingAction: Binding<(() -> Void)?> = .constant(nil),
    onTranscription: ((String) -> Void)? = nil,
    onDismiss: (() -> Void)? = nil,
    ttsSpeaker: TTSSpeaker? = nil,
    executor: ClaudeCodeExecutor? = nil
  ) {
    self.mode = mode
    self.height = height
    self.presentationMode = presentationMode
    self._transcribedText = transcribedText
    self._stopRecordingAction = stopRecordingAction
    self.onTranscription = onTranscription
    self.onDismiss = onDismiss
    self.ttsSpeaker = ttsSpeaker
    self.executor = executor
  }
  
  // MARK: - Body
  
  public var body: some View {
    Group {
      switch mode {
      case .stt:
        STTModeView(
          height: height,
          transcribedText: $transcribedText,
          stopRecordingAction: $stopRecordingAction,
          onTranscription: onTranscription,
          onDismiss: onDismiss
        )

      case .sttWithTTS:
        // Use STTModeView with TTSSpeaker for combined STT+TTS mode
        STTModeView(
          height: height,
          ttsSpeaker: ttsSpeaker,
          transcribedText: $transcribedText,
          stopRecordingAction: $stopRecordingAction,
          onTranscription: onTranscription,
          onDismiss: nil  // Don't auto-dismiss, TTS may be playing
        )
      case .realtime:
        realtimeModeBody
      }
    }
    .animation(.easeInOut(duration: 0.2), value: mode)
  }
  
  // MARK: - Realtime Mode Body (existing implementation)
  
  private var realtimeModeBody: some View {
    HStack(spacing: 8) {
      // Left buttons
      leftButtons
      
      // Center: Audio visualizer
      audioVisualizer
      
      // Right buttons
      rightButtons
    }
    .padding(.horizontal, 12)
    .frame(height: height)
    .frame(maxWidth: .infinity)
    .background {
      glassBackground
    }
    .overlay {
      // Error indicator (subtle for inline view)
      if conversationManager.errorMessage != nil {
        errorIndicator
      }
    }
    .animation(.easeInOut(duration: 0.2), value: conversationManager.isExecutingTool)
    .animation(.easeInOut(duration: 0.2), value: conversationManager.errorMessage == nil)
    .task {
      await startConversation()
    }
    .sheet(isPresented: $showScreenshotPicker) {
      ScreenshotPickerView { base64DataURL in
        Task {
          await conversationManager.sendImage(base64DataURL)
        }
      }
    }
  }
  
  // MARK: - Realtime Mode Components
  
  private var leftButtons: some View {
    HStack(spacing: 6) {
      screenshotButton
      muteButton
    }
  }
  
  private var rightButtons: some View {
    HStack(spacing: 6) {
      if conversationManager.isExecutingTool {
        stopProcessButton
      }
      if presentationMode == .presented {
        closeButton
      }
    }
  }
  
  private var screenshotButton: some View {
    Button {
      showScreenshotPicker = true
    } label: {
      Image(systemName: "camera.viewfinder")
        .font(.system(size: 18))
        .foregroundStyle(.white.opacity(0.7))
    }
    .buttonStyle(.plain)
    .disabled(!conversationManager.isConnected)
    .opacity(conversationManager.isConnected ? 1.0 : 0.5)
    .help("Capture and send screenshot")
  }
  
  private var muteButton: some View {
    Button {
      conversationManager.toggleMicrophoneMute()
    } label: {
      Image(systemName: conversationManager.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill")
        .font(.system(size: 18))
        .foregroundStyle(conversationManager.isMicrophoneMuted ? .pink : .white.opacity(0.7))
    }
    .disabled(!conversationManager.isConnected)
    .buttonStyle(.plain)
    .opacity(conversationManager.isConnected ? 1.0 : 0.5)
    .help(conversationManager.isMicrophoneMuted ? "Unmute microphone (⌘M)" : "Mute microphone (⌘M)")
    .keyboardShortcut("m", modifiers: .command)
  }
  
  private var closeButton: some View {
    Button {
      conversationManager.stopConversation()
      dismiss()
    } label: {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 18))
        .foregroundStyle(.white.opacity(0.7))
    }
    .buttonStyle(.plain)
    .help("Close (⌘W)")
    .keyboardShortcut("w", modifiers: .command)
  }
  
  private var stopProcessButton: some View {
    Button {
      conversationManager.cancelToolExecution()
    } label: {
      Text("Stop")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          Capsule()
            .fill(Color.orange.opacity(0.6))
        )
    }
    .buttonStyle(.plain)
    .transition(.opacity.combined(with: .scale(scale: 0.9)))
  }
  
  private var audioVisualizer: some View {
    InlineAudioVisualizerView(conversationManager: conversationManager)
      .frame(maxWidth: .infinity)
      .frame(height: height - 12) // Leave some padding
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
  
  // MARK: - Shared Components
  
  @ViewBuilder
  private var glassBackground: some View {
#if os(visionOS)
    Color.clear.glassBackgroundEffect()
#else
    RoundedRectangle(cornerRadius: 12)
      .fill(.ultraThinMaterial)
#endif
  }
  
  private var errorIndicator: some View {
    HStack {
      Spacer()
      Circle()
        .fill(Color.red)
        .frame(width: 8, height: 8)
        .overlay(
          Circle()
            .stroke(Color.red.opacity(0.5), lineWidth: 2)
            .scaleEffect(1.5)
        )
      Spacer()
    }
    .padding(.top, 2)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .allowsHitTesting(false)
  }
  
  // MARK: - Realtime Mode Methods
  
  private func startConversation() async {
    guard let service = serviceManager.service else {
      isInitializing = false
      return
    }
    
    isInitializing = true
    conversationManager.setSettingsManager(settingsManager)
    
    // Set the ClaudeCodeExecutor if provided
    if let executor = executor {
      conversationManager.setClaudeCodeExecutor(executor)
    }
    
    let configuration = serviceManager.createSessionConfiguration()
    await conversationManager.startConversation(service: service, configuration: configuration)
    isInitializing = false
  }
}

// MARK: - Previews

#Preview("Realtime Mode") {
  VStack {
    Spacer()
    InlineVoiceModeView()
      .padding()
    Spacer()
  }
  .background(Color.black)
  .environment(OpenAIServiceManager())
  .environment(SettingsManager())
}

#Preview("STT Mode") {
  VStack {
    Spacer()
    InlineVoiceModeView(
      mode: .stt,
      onTranscription: { text in
        print("Transcribed: \(text)")
      }
    )
    .padding()
    Spacer()
  }
  .background(Color.black)
  .environment(OpenAIServiceManager())
  .environment(SettingsManager())
}

#Preview("STT with TTS Mode") {
  VStack {
    Spacer()
    InlineVoiceModeView(
      mode: .sttWithTTS,
      onTranscription: { text in
        print("User said: \(text)")
        // Parent would send to API, then call speaker.speak(response)
      },
      ttsSpeaker: TTSSpeaker()
    )
    .padding()
    Spacer()
  }
  .background(Color.black)
  .environment(OpenAIServiceManager())
  .environment(SettingsManager())
}
