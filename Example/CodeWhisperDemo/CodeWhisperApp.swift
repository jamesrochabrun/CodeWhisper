//
//  CodeWhisperApp.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI
import CodeWhisper

enum VoiceModeStyle: String, CaseIterable {
  case full = "Full"
  case inline = "Inline"
}

enum DemoOption: String, CaseIterable, Identifiable {
  case voiceModes = "Voice Modes Demo"
  case floatingButton = "Floating Button"
  case floatingButtonEmbedded = "Floating Button (Embedded)"

  var id: String { rawValue }

  var description: String {
    switch self {
    case .voiceModes:
      return "Full and Inline voice mode demonstrations"
    case .floatingButton:
      return "Launch a floating STT button on screen"
    case .floatingButtonEmbedded:
      return "Floating button without menu bar - hover for settings"
    }
  }

  var systemImage: String {
    switch self {
    case .voiceModes:
      return "waveform"
    case .floatingButton:
      return "bubble.left.and.bubble.right"
    case .floatingButtonEmbedded:
      return "bubble.left.and.bubble.right.fill"
    }
  }
}

@main
struct CodeWhisperApp: App {
  @State private var settingsManager = SettingsManager()
  @State private var mcpServerManager = MCPServerManager()
  @State private var serviceManager = OpenAIServiceManager()
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(settingsManager)
        .environment(mcpServerManager)
        .environment(serviceManager)
        .onChange(of: settingsManager.apiKey) { _, newValue in
          serviceManager.updateService(apiKey: newValue)
        }
        .onChange(of: settingsManager.realtimeLanguageCode) { _, newValue in
          serviceManager.transcriptionLanguage = newValue
        }
        .onChange(of: mcpServerManager.servers) { _, _ in
          // Notify service manager that MCP servers changed
          serviceManager.mcpServersDidChange()
        }
        .onAppear {
          // Initialize service on app launch
          serviceManager.updateService(apiKey: settingsManager.apiKey)
          serviceManager.transcriptionLanguage = settingsManager.realtimeLanguageCode
          serviceManager.setMCPServerManager(mcpServerManager)
        }
    }
    .windowStyle(.hiddenTitleBar) // Hides title bar, keeps traffic lights
    .windowStyle(.titleBar)        // Standard title bar
    .windowStyle(.automatic)       // System default
  }
}

// MARK: - Content View

struct ContentView: View {
  @Environment(SettingsManager.self) private var settingsManager

  var body: some View {
    NavigationStack {
      DemoListView()
    }
  }
}

// MARK: - Demo List View

struct DemoListView: View {
  @Environment(SettingsManager.self) private var settingsManager

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      List {
        ForEach(DemoOption.allCases) { option in
          switch option {
          case .voiceModes:
            NavigationLink(value: option) {
              DemoOptionRow(option: option)
            }
          case .floatingButton:
            Button {
              launchFloatingButton()
            } label: {
              DemoOptionRow(option: option)
            }
            .buttonStyle(.plain)
          case .floatingButtonEmbedded:
            Button {
              toggleFloatingButtonEmbedded()
            } label: {
              DemoOptionRow(option: option)
            }
            .buttonStyle(.plain)
          }
        }
        .listRowBackground(Color.white.opacity(0.05))
      }
      .scrollContentBackground(.hidden)
      .navigationDestination(for: DemoOption.self) { option in
        switch option {
        case .voiceModes:
          VoiceModesView()
        case .floatingButton, .floatingButtonEmbedded:
          EmptyView()
        }
      }
    }
    .navigationTitle("CodeWhisper Demo")
  }

  private func launchFloatingButton() {
    #if os(macOS)
    FloatingSTT.configure(apiKey: settingsManager.apiKey, enableEnhancement: true)
    FloatingSTT.show()
    #endif
  }

  private func toggleFloatingButtonEmbedded() {
    #if os(macOS)
    // Only configure if not already visible
    if !FloatingSTT.isVisible {
      FloatingSTT.configure(apiKey: settingsManager.apiKey, embedded: true, enableEnhancement: true)
    }
    FloatingSTT.toggle()
    #endif
  }
}

// MARK: - Demo Option Row

struct DemoOptionRow: View {
  let option: DemoOption

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: option.systemImage)
        .font(.title2)
        .foregroundStyle(.blue)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 4) {
        Text(option.rawValue)
          .font(.headline)
          .foregroundStyle(.white)
        Text(option.description)
          .font(.caption)
          .foregroundStyle(.gray)
      }

      Spacer()
    }
    .padding(.vertical, 8)
  }
}

// MARK: - Voice Modes View

struct VoiceModesView: View {
  @State private var selectedStyle: VoiceModeStyle = .full

  var body: some View {
    ZStack(alignment: .top) {
      Color.black.ignoresSafeArea()

      VStack(spacing: 0) {
        // Style picker
        Picker("Style", selection: $selectedStyle) {
          ForEach(VoiceModeStyle.allCases, id: \.self) { style in
            Text(style.rawValue).tag(style)
          }
        }
        .pickerStyle(.segmented)
        .padding()

        // Content based on selected style
        switch selectedStyle {
        case .full:
          VoiceModeView()
        case .inline:
          // Mock chat UI with InlineVoiceModeView at bottom
          VStack {
            // Mock chat messages area
            ScrollView {
              VStack(alignment: .leading, spacing: 12) {
                mockMessage("Hello! How can I help you today?", isUser: false)
                mockMessage("I'd like to try the inline voice mode.", isUser: true)
                mockMessage("Great choice! The inline voice mode provides a compact interface that can be embedded in chat UIs.", isUser: false)
              }
              .padding()
            }

            Spacer()

            // Inline voice mode at bottom
            InlineVoiceModeView()
              .padding(.horizontal)
              .padding(.bottom, 16)
          }
        }
      }
    }
    .navigationTitle("Voice Modes")
  }

  @ViewBuilder
  private func mockMessage(_ text: String, isUser: Bool) -> some View {
    HStack {
      if isUser { Spacer() }
      Text(text)
        .font(.system(size: 14))
        .foregroundStyle(.white)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(isUser ? Color.blue.opacity(0.6) : Color.white.opacity(0.1))
        )
        .frame(maxWidth: 300, alignment: isUser ? .trailing : .leading)
      if !isUser { Spacer() }
    }
  }
}
