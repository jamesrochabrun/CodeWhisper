//
//  VoiceModeView.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

struct VoiceModeView: View {
  @Environment(OpenAIServiceManager.self) private var serviceManager
  @Environment(\.dismiss) private var dismiss
  @State private var conversationManager = ConversationManager()
  @State private var isInitializing = true
  @State private var showScreenshotPicker = false

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
          .frame(width: 300, height: 300)
        
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
        
        Spacer()
        
        // Controls
        HStack(spacing: 40) {
          // Could add more controls here in the future
        }
        .padding(.bottom, 40)
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
  
  private func startConversation() async {
    guard let service = serviceManager.service else {
      // Service not available - this shouldn't happen if ContentView validates correctly
      // ConversationManager will handle showing the error
      isInitializing = false
      return
    }

    isInitializing = true
    let configuration = serviceManager.createSessionConfiguration()
    await conversationManager.startConversation(service: service, configuration: configuration)
    isInitializing = false
  }
}

#Preview {
  VoiceModeView()
    .environment(OpenAIServiceManager())
}
