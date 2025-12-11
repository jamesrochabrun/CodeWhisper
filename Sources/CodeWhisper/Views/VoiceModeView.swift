//
//  VoiceModeView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

public struct VoiceModeView: View {
  
  public enum PresentationMode {
    case standalone
    case presented
  }
  
  @Environment(OpenAIServiceManager.self) private var serviceManager
  @Environment(SettingsManager.self) private var settingsManager
  @Environment(\.dismiss) private var dismiss
  @State private var conversationManager = ConversationManager()
  @State private var isInitializing = true
  @State private var showScreenshotPicker = false
  @State private var textInput: String = ""
  @FocusState private var isTextFieldFocused: Bool
  
  private let presentationMode: PresentationMode
  private let executor: ClaudeCodeExecutor?
  
  public init(presentationMode: PresentationMode = .standalone, executor: ClaudeCodeExecutor? = nil) {
    self.presentationMode = presentationMode
    self.executor = executor
  }
  
  public var body: some View {
    ZStack(alignment: .top) {
      Color.black.ignoresSafeArea()
      VStack(spacing: 30) {
        toolbar
        // Error banner (for critical errors)
        if let errorMessage = conversationManager.errorMessage {
          errorBanner(errorMessage)
        }
        audioVisualizer
        conversationTranscript
        if conversationManager.isExecutingTool {
          toolExecutionIndicator
        }
        textInputSection
      }
      .animation(.easeInOut, value: conversationManager.isExecutingTool)
      .animation(.easeInOut, value: conversationManager.errorMessage == nil)
    }
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
  
  // MARK: - Computed Properties
  
  private var canSendText: Bool {
    conversationManager.isConnected && !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  // MARK: - View Components
  
  private var toolbar: some View {
    VStack(spacing: 8) {
      workingDirectoryDisplay
      HStack {
        screenshotButton
        muteButton
        Spacer()
        if presentationMode == .presented {
          closeButton
        }
      }
    }
    .padding()
  }
  
  private var screenshotButton: some View {
    Button {
      showScreenshotPicker = true
    } label: {
      Image(systemName: "camera.viewfinder")
        .font(.system(size: 28))
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
        .font(.system(size: 28))
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
        .font(.system(size: 28))
        .foregroundStyle(.white.opacity(0.7))
    }
    .buttonStyle(.plain)
    .help("Close (⌘W)")
    .keyboardShortcut("w", modifiers: .command)
  }
  
  private var audioVisualizer: some View {
    SimpleAudioVisualizerView(conversationManager: conversationManager)
      .frame(width: 200, height: 200)
  }
  
  private var conversationTranscript: some View {
    ConversationTranscriptView(messages: conversationManager.messages)
      .frame(height: 150)
      .frame(maxWidth: 500)
  }
  
  private var toolExecutionIndicator: some View {
    Button {
      conversationManager.cancelToolExecution()
    } label: {
      Text("Stop process")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
          Capsule()
            .fill(Color.orange.opacity(0.6))
        )
    }
    .buttonStyle(.plain)
    .transition(.opacity.combined(with: .scale(scale: 0.9)))
    .animation(.easeInOut(duration: 0.2), value: conversationManager.isExecutingTool)
  }
  
  private var textInputSection: some View {
    VStack(spacing: 10) {
      // Warning banner (for non-critical warnings like screenshot issues)
      if let warningMessage = conversationManager.warningMessage {
        warningBanner(warningMessage)
      }
      HStack(spacing: 12) {
        textField
        sendButton
      }
      .padding(.horizontal, 40)
      .frame(maxWidth: 600)
      .padding(.bottom, 24)
    }
  }
  
  private var textField: some View {
    TextField("Type a message or paste a URL...", text: $textInput)
      .textFieldStyle(.plain)
      .padding(12)
      .background(Color.white.opacity(0.1))
      .foregroundStyle(.white)
      .cornerRadius(8)
      .focused($isTextFieldFocused)
      .disabled(!conversationManager.isConnected)
      .onSubmit {
        sendTextMessage()
      }
  }
  
  private var sendButton: some View {
    Button {
      sendTextMessage()
    } label: {
      Image(systemName: "arrow.up.circle.fill")
        .font(.system(size: 32))
        .foregroundStyle(canSendText ? .blue : .gray)
    }
    .buttonStyle(.plain)
    .disabled(!canSendText)
    .help("Send message")
  }
  
  private var workingDirectoryDisplay: some View {
    Text(settingsManager.workingDirectory)
      .font(.system(size: 10, design: .monospaced))
      .foregroundColor(.secondary)
      .padding(.leading, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
  
  // MARK: - Methods
  
  private func sendTextMessage() {
    guard canSendText else { return }
    
    let messageToSend = textInput
    textInput = ""
    isTextFieldFocused = false
    
    Task {
      await conversationManager.sendText(messageToSend)
    }
  }
  
  @ViewBuilder
  private func errorBanner(_ message: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 16))
        .foregroundStyle(.yellow)
      
      VStack(alignment: .leading, spacing: 4) {
        Text("Error")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.white)
        Text(message)
          .font(.system(size: 10))
          .foregroundStyle(.white.opacity(0.9))
          .fixedSize(horizontal: false, vertical: true)
      }
      
      Spacer()
      
      Button {
        conversationManager.clearError()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(.white.opacity(0.7))
      }
      .buttonStyle(.plain)
      .help("Dismiss error")
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.red.opacity(0.7))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    )
    .padding(.horizontal)
    .transition(.move(edge: .top).combined(with: .opacity))
  }
  
  @ViewBuilder
  private func warningBanner(_ message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.circle.fill")
        .font(.system(size: 14))
        .foregroundStyle(.orange)
      
      Text(message)
        .font(.system(size: 10))
        .foregroundStyle(.orange.opacity(0.9))
        .lineLimit(2)
      
      Spacer()
      
      Button {
        conversationManager.clearWarning()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 16))
          .foregroundStyle(.orange.opacity(0.6))
      }
      .buttonStyle(.plain)
      .help("Dismiss warning")
    }
    .padding(12)
    .padding(.horizontal)
    .transition(.move(edge: .top).combined(with: .opacity))
  }
  
  private func startConversation() async {
    guard let service = serviceManager.service else {
      isInitializing = false
      return
    }

    isInitializing = true
    conversationManager.setSettingsManager(settingsManager)

    // Sync language setting to service manager
    serviceManager.transcriptionLanguage = settingsManager.realtimeLanguageCode

    // Set the ClaudeCodeExecutor if provided
    // This allows integration with existing Claude Code configurations
    if let executor = executor {
      conversationManager.setClaudeCodeExecutor(executor)
    }

    let configuration = serviceManager.createSessionConfiguration()
    await conversationManager.startConversation(service: service, configuration: configuration)
    isInitializing = false
  }
}

#Preview {
  VoiceModeView()
    .environment(OpenAIServiceManager())
}
