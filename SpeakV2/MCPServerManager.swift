//
//  MCPServerManager.swift
//  SpeakV2
//
//  MCP Server configuration management
//

import Foundation
import SwiftUI
import Observation

/// Configuration for a single MCP server
struct MCPServerConfig: Codable, Identifiable, Equatable {
  var id = UUID()
  var label: String
  var serverUrl: String
  var authorization: String?
  var requireApproval: String // "never", "always", or filters

  enum CodingKeys: String, CodingKey {
    case id, label, serverUrl, authorization, requireApproval
  }
}

/// Manages MCP server configurations
@Observable
@MainActor
final class MCPServerManager {
  private(set) var servers: [MCPServerConfig] = []

  private let userDefaultsKey = "MCPServers"

  init() {
    loadServers()
    removeDuplicates()
  }

  /// Remove duplicate servers with the same label
  private func removeDuplicates() {
    let originalCount = servers.count
    var seenLabels = Set<String>()
    var uniqueServers: [MCPServerConfig] = []

    for server in servers {
      if !seenLabels.contains(server.label) {
        seenLabels.insert(server.label)
        uniqueServers.append(server)
      } else {
        print("⚠️ Removing duplicate MCP server with label: \(server.label)")
      }
    }

    if uniqueServers.count != originalCount {
      servers = uniqueServers
      saveServers()
      print("✅ Removed \(originalCount - uniqueServers.count) duplicate server(s)")
    }
  }

  // MARK: - CRUD Operations

  func addServer(_ config: MCPServerConfig) {
    // Check for duplicate label
    if servers.contains(where: { $0.label == config.label }) {
      print("⚠️ Cannot add server: label '\(config.label)' already exists")
      return
    }
    servers.append(config)
    saveServers()
  }

  func updateServer(_ config: MCPServerConfig) {
    if let index = servers.firstIndex(where: { $0.id == config.id }) {
      servers[index] = config
      saveServers()
    }
  }

  func deleteServer(_ config: MCPServerConfig) {
    servers.removeAll { $0.id == config.id }
    saveServers()
  }

  func deleteServers(at offsets: IndexSet) {
    servers.remove(atOffsets: offsets)
    saveServers()
  }

  // MARK: - Persistence

  private func saveServers() {
    do {
      let data = try JSONEncoder().encode(servers)
      UserDefaults.standard.set(data, forKey: userDefaultsKey)
    } catch {
      print("Failed to save MCP servers: \(error)")
    }
  }

  private func loadServers() {
    guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
      // Initialize with empty array if no data
      servers = []
      return
    }

    do {
      servers = try JSONDecoder().decode([MCPServerConfig].self, from: data)
    } catch {
      print("Failed to load MCP servers: \(error)")
      servers = []
    }
  }

  // MARK: - Convenience Methods

  func server(withLabel label: String) -> MCPServerConfig? {
    servers.first { $0.label == label }
  }

  var hasServers: Bool {
    !servers.isEmpty
  }

  // MARK: - Sample Data (for testing)

  func addSampleServer() {
    let sample = MCPServerConfig(
      label: "stripe",
      serverUrl: "https://mcp.stripe.com",
      authorization: nil,
      requireApproval: "never"
    )
    addServer(sample)
  }
}
