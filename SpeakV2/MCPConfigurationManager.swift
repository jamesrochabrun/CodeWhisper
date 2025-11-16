//
//  MCPConfigurationManager.swift
//  SpeakV2
//
//  Manages MCP configuration file and approval server integration
//

import Foundation
import Observation

@Observable
@MainActor
final class MCPConfigurationManager {
  var configuration: MCPFileConfiguration

  private let configFileName = "mcp-config.json"
  private var configFileURL: URL? {
    // Use Claude Code's default configuration location
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    return homeURL
      .appendingPathComponent(".config")
      .appendingPathComponent("claude")
      .appendingPathComponent(configFileName)
  }

  init() {
    self.configuration = MCPFileConfiguration()
    loadConfiguration()
  }

  // MARK: - File Management

  func saveConfiguration() {
    guard let url = configFileURL else {
      print("[MCPPERMISSION] ❌ No config file URL available")
      return
    }

    do {
      // Create directory if needed
      let directory = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      print("[MCPPERMISSION] ✅ Directory created/verified: \(directory.path)")

      // Encode and save
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(configuration)
      try data.write(to: url)
      print("[MCPPERMISSION] ✅ Configuration saved to: \(url.path)")
      print("[MCPPERMISSION] 📋 Servers configured: \(configuration.mcpServers.keys.joined(separator: ", "))")

      // Log approval_server details if present
      if let approvalServer = configuration.mcpServers["approval_server"] {
        print("[MCPPERMISSION] 🔧 approval_server command: \(approvalServer.command)")
        print("[MCPPERMISSION] 🔧 approval_server args: \(approvalServer.args)")
      }
    } catch {
      print("[MCPPERMISSION] ❌ Failed to save configuration: \(error)")
    }
  }

  func loadConfiguration() {
    guard let url = configFileURL,
          FileManager.default.fileExists(atPath: url.path) else {
      // Load default configuration
      loadDefaultConfiguration()
      return
    }

    do {
      let data = try Data(contentsOf: url)
      configuration = try JSONDecoder().decode(MCPFileConfiguration.self, from: data)
    } catch {
      print("Failed to load MCP configuration: \(error)")
      loadDefaultConfiguration()
    }
  }

  private func loadDefaultConfiguration() {
    configuration = MCPFileConfiguration()
  }

  func getConfigurationPath() -> String? {
    let path = configFileURL?.path
    print("[MCPPERMISSION] 📍 Config path requested: \(path ?? "nil")")
    return path
  }

  // MARK: - Server Management

  func addServer(_ server: MCPStdioServerConfig) {
    print("[MCP] Adding server: \(server.name)")
    configuration.mcpServers[server.name] = server
    saveConfiguration()
  }

  func removeServer(named name: String) {
    configuration.mcpServers.removeValue(forKey: name)
    saveConfiguration()
  }

  func updateServer(_ server: MCPStdioServerConfig) {
    configuration.mcpServers[server.name] = server
    saveConfiguration()
  }

  // MARK: - Approval Server Management

  /// Updates the approval server path in the MCP configuration
  /// This ensures the config always points to the bundled binary
  func updateApprovalServerPath() {
    print("[MCPPERMISSION] 🔍 Searching for ApprovalMCPServer in bundle...")
    print("[MCPPERMISSION] 📦 Bundle path: \(Bundle.main.bundlePath)")

    // Check if ApprovalMCPServer exists in the app bundle
    guard let bundlePath = Bundle.main.path(forResource: "ApprovalMCPServer", ofType: nil) else {
      print("[MCPPERMISSION] ❌ Bundle.main.path returned nil for ApprovalMCPServer")
      print("[MCPPERMISSION] 🔍 Checking Resources directory manually...")

      let resourcesPath = Bundle.main.resourcePath ?? ""
      let manualPath = resourcesPath + "/ApprovalMCPServer"
      print("[MCPPERMISSION] 📂 Manual check path: \(manualPath)")
      print("[MCPPERMISSION] 📂 File exists: \(FileManager.default.fileExists(atPath: manualPath))")

      // Remove approval_server if binary doesn't exist
      if configuration.mcpServers["approval_server"] != nil {
        print("[MCPPERMISSION] 🗑️ Removing approval_server from config (binary not found)")
        configuration.mcpServers.removeValue(forKey: "approval_server")
        saveConfiguration()
      }
      return
    }

    print("[MCPPERMISSION] ✅ Found ApprovalMCPServer at: \(bundlePath)")
    print("[MCPPERMISSION] 📂 File exists: \(FileManager.default.fileExists(atPath: bundlePath))")

    // Check if approval_server already exists and has correct path
    if let existingServer = configuration.mcpServers["approval_server"],
       existingServer.command == bundlePath {
      print("[MCPPERMISSION] ℹ️ Approval server already configured with correct path")
      return
    }

    // Update or add the approval_server configuration
    let approvalServer = MCPStdioServerConfig(
      name: "approval_server",
      command: bundlePath,
      args: []
    )
    configuration.mcpServers["approval_server"] = approvalServer
    print("[MCPPERMISSION] ✅ Updated approval_server in configuration")
    saveConfiguration()
  }

  // MARK: - Export/Import

  func exportConfiguration(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(configuration)
    try data.write(to: url)
  }

  func importConfiguration(from url: URL) throws {
    let data = try Data(contentsOf: url)
    configuration = try JSONDecoder().decode(MCPFileConfiguration.self, from: data)
    saveConfiguration()
  }
}
