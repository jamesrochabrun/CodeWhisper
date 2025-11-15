//
//  VoiceModeView.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI
import ClaudeCodeCore

struct VoiceModeView: View {
  @Environment(OpenAIServiceManager.self) private var serviceManager
  @Environment(\.dismiss) private var dismiss
  @State private var conversationManager = ConversationManager()
  @State private var isInitializing = true
  @State private var showScreenshotPicker = false
  @State private var textInput: String = ""
  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
    ZStack(alignment: .top) {
      Color.black.ignoresSafeArea()
      VStack(spacing: 30) {
        toolbar
        audioVisualizer
        conversationTranscript
        textInputSection
      }
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
    HStack {
      screenshotButton
      muteButton
      Spacer()
      closeButton
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
        .foregroundStyle(conversationManager.isMicrophoneMuted ? .red : .white.opacity(0.7))
    }
    .disabled(!conversationManager.isConnected)
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
        .font(.system(size: 32))
        .foregroundStyle(.white.opacity(0.7))
    }
  }

  private var audioVisualizer: some View {
    SwiftUIAudioVisualizerView(conversationManager: conversationManager)
      .frame(width: 200, height: 200)
  }

  private var conversationTranscript: some View {
    ConversationTranscriptView(messages: conversationManager.messages)
      .frame(height: 150)
      .frame(maxWidth: 500)
  }

  private var textInputSection: some View {
    HStack(spacing: 12) {
      textField
      sendButton
    }
    .padding(.horizontal, 40)
    .padding(.bottom, 40)
    .frame(maxWidth: 600)
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

  private func startConversation() async {
    guard let service = serviceManager.service else {
      isInitializing = false
      return
    }

    isInitializing = true
    conversationManager.initializeClaudeCode()

    let configuration = serviceManager.createSessionConfiguration()
    await conversationManager.startConversation(service: service, configuration: configuration)
    isInitializing = false
  }
}

#Preview {
  VoiceModeView()
    .environment(OpenAIServiceManager())
}
