//
//  CodeWhisperApp.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI
import CodeWhisper

@main
struct CodeWhisperApp: App {
  @State private var settingsManager = SettingsManager()
  @State private var mcpServerManager = MCPServerManager()
  @State private var serviceManager = OpenAIServiceManager()

  var body: some Scene {
    WindowGroup {
      VoiceModeView()
        .environment(settingsManager)
        .environment(mcpServerManager)
        .environment(serviceManager)
        .onChange(of: settingsManager.apiKey) { _, newValue in
          serviceManager.updateService(apiKey: newValue)
        }
        .onChange(of: mcpServerManager.servers) { _, _ in
          // Notify service manager that MCP servers changed
          serviceManager.mcpServersDidChange()
        }
        .onAppear {
          // Initialize service on app launch
          serviceManager.updateService(apiKey: settingsManager.apiKey)
          serviceManager.setMCPServerManager(mcpServerManager)
        }
    }
    .windowStyle(.hiddenTitleBar) // Hides title bar, keeps traffic lights
    .windowStyle(.titleBar)        // Standard title bar
    .windowStyle(.automatic)       // System default
  }
}
