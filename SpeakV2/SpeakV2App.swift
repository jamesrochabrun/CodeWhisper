//
//  SpeakV2App.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

@main
struct SpeakV2App: App {
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
  }
}
