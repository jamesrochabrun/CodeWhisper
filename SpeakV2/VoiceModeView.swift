//
//  VoiceModeView.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

struct VoiceModeView: View {
  let settingsManager: SettingsManager
  @Environment(\.dismiss) private var dismiss
  @State private var conversationManager = ConversationManager()
  @State private var isInitializing = true
  
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      
      VStack(spacing: 30) {
        // Close button
        HStack {
          Spacer()
          Button {
            conversationManager.stopConversation()
            dismiss()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 32))
              .foregroundStyle(.white.opacity(0.7))
          }
          .padding()
        }
        
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
  }
  
  private func startConversation() async {
    isInitializing = true
    print("VoiceModeView.startConversation - API key length: \(settingsManager.apiKey.count)")
    print("VoiceModeView.startConversation - Has newlines: \(settingsManager.apiKey.contains("\n"))")
    await conversationManager.startConversation(apiKey: settingsManager.apiKey)
    isInitializing = false
  }
}

#Preview {
  VoiceModeView(settingsManager: SettingsManager())
}
