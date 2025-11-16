//
//  ContentView.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

struct ContentView: View {
  @Environment(SettingsManager.self) private var settingsManager
  @Environment(OpenAIServiceManager.self) private var serviceManager
  @State private var showingVoiceMode = false
  @State private var showingSettings = false
  
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      
      VStack(spacing: 40) {
        Spacer()
        
        Text("SpeakV2")
          .font(.system(size: 60, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
        
        Text("Real-time voice conversations with AI")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .padding(.horizontal)
        
        Spacer()
        
        Button {
          if serviceManager.hasValidService {
            showingVoiceMode = true
          } else {
            showingSettings = true
          }
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
              .font(.title2)
            Text("Start Voice Mode")
              .font(.title3)
              .fontWeight(.semibold)
          }
          .foregroundStyle(.black)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background {
            RoundedRectangle(cornerRadius: 16)
              .fill(.white)
          }
        }
        .padding(.horizontal, 40)
        
        Button {
          showingSettings = true
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "gear")
            Text("Settings")
          }
          .foregroundStyle(.white.opacity(0.7))
          .padding(.vertical, 12)
        }
        
        Spacer()
      }
    }
    .sheet(isPresented: $showingSettings) {
      SettingsView()
    }
#if os(macOS)
    .sheet(isPresented: $showingVoiceMode) {
      VoiceModeView()
    }
#else
    .fullScreenCover(isPresented: $showingVoiceMode) {
      VoiceModeView()
    }
#endif
  }
}

#Preview {
  ContentView()
}
