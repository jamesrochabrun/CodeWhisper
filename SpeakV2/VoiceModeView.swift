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
    ZStack {
      Color.black.ignoresSafeArea()
      
      VStack(spacing: 30) {
        // Top toolbar
        HStack {
          // Screenshot button
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

          // Mute button
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

          Spacer()

          // Close button
          Button {
            conversationManager.stopConversation()
            dismiss()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 32))
              .foregroundStyle(.white.opacity(0.7))
          }
        }
        .padding()
        
        Spacer()
        
        // Audio visualizer
        SwiftUIAudioVisualizerView(conversationManager: conversationManager)
          .frame(width: 200, height: 200)
        
        
        // Conversation transcript
        ConversationTranscriptView(messages: conversationManager.messages)
          .frame(height: 220)
          .frame(maxWidth: 500)
        
        // Status text
        VStack(spacing: 12) {
          if isInitializing {
            ProgressView()
              .tint(.white)
            Text("Initializing...")
              .font(.title3)
              .foregroundStyle(.white.opacity(0.7))
          } else if conversationManager.isConnected {
            Image(systemName: conversationManager.isListening ? "waveform" : "waveform.slash")
              .font(.title)
              .foregroundStyle(.white)
            Text(conversationManager.isListening ? "Listening..." : "Connected")
              .font(.title2)
              .fontWeight(.medium)
              .foregroundStyle(.white)
            Text("Speak naturally to have a conversation")
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.6))
          } else {
            Image(systemName: "exclamationmark.triangle")
              .font(.title)
              .foregroundStyle(.yellow)
            Text("Not Connected")
              .font(.title2)
              .foregroundStyle(.white)
            if let error = conversationManager.errorMessage {
              Text(error)
                .font(.subheadline)
                .foregroundStyle(.red.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
          }
        }
        .frame(height: 120)
                
        // Text input controls
        HStack(spacing: 12) {
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
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: 600)
      }
    }
    .frame(height: 900)
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
  
  /// Check if text can be sent
  private var canSendText: Bool {
    conversationManager.isConnected && !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  /// Send text message and clear input
  private func sendTextMessage() {
    guard canSendText else { return }
    
    let messageToSend = textInput
    textInput = "" // Clear input immediately
    isTextFieldFocused = false // Remove focus
    
    Task {
      await conversationManager.sendText(messageToSend)
    }
  }
  
  private func startConversation() async {
    guard let service = serviceManager.service else {
      // Service not available - this shouldn't happen if ContentView validates correctly
      // ConversationManager will handle showing the error
      isInitializing = false
      return
    }

    isInitializing = true

    // Initialize Claude Code integration
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
