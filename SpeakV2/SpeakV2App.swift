//
//  SpeakV2App.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI
import ClaudeCodeCore
import CCCustomPermissionService

@main
struct SpeakV2App: App {
  @State private var settingsManager = SettingsManager()
  @State private var mcpServerManager = MCPServerManager()
  @State private var serviceManager = OpenAIServiceManager()

  // Permission service and approval bridge for Claude Code approval dialogs
  @State private var permissionService = DefaultCustomPermissionService()
  @State private var approvalBridge: ApprovalBridge?

  var body: some Scene {
    WindowGroup {
      ContentView(permissionService: permissionService)
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

          // Initialize ApprovalBridge to listen for IPC approval requests
          initializeApprovalBridge()
        }
    }
  }

  /// Initialize the ApprovalBridge to listen for distributed notifications
  /// from the ApprovalMCPServer subprocess
  private func initializeApprovalBridge() {
    Task { @MainActor in
      print("[MCPPERMISSION] 🚀 Initializing ApprovalBridge...")
      let bridge = ApprovalBridge(permissionService: permissionService)
      self.approvalBridge = bridge
      print("[MCPPERMISSION] ✅ ApprovalBridge initialized - listening for IPC approval requests")
    }
  }
}
