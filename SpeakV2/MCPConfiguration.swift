//
//  MCPConfiguration.swift
//  SpeakV2
//
//  MCP Configuration models for approval server integration
//

import Foundation

// MARK: - MCP Configuration Models

struct MCPFileConfiguration: Codable {
  var mcpServers: [String: MCPStdioServerConfig]

  init(mcpServers: [String: MCPStdioServerConfig] = [:]) {
    self.mcpServers = mcpServers
  }

  // Custom encoding/decoding to handle the server names as dictionary keys
  enum CodingKeys: String, CodingKey {
    case mcpServers
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let serverDict = try container.decode([String: MCPStdioServerConfig.ServerData].self, forKey: .mcpServers)

    // Convert ServerData to MCPStdioServerConfig with names
    self.mcpServers = serverDict.reduce(into: [:]) { result, pair in
      result[pair.key] = MCPStdioServerConfig(
        name: pair.key,
        command: pair.value.command ?? "",
        args: pair.value.args ?? [],
        env: pair.value.env
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    // Convert MCPStdioServerConfig to ServerData for encoding
    let serverDict = mcpServers.reduce(into: [String: MCPStdioServerConfig.ServerData]()) { result, pair in
      result[pair.key] = MCPStdioServerConfig.ServerData(
        command: pair.value.command.isEmpty ? nil : pair.value.command,
        args: pair.value.args.isEmpty ? nil : pair.value.args,
        env: pair.value.env
      )
    }

    try container.encode(serverDict, forKey: .mcpServers)
  }
}

struct MCPStdioServerConfig: Identifiable {
  var id: String { name }
  let name: String
  var command: String
  var args: [String]
  var env: [String: String]?

  init(name: String, command: String = "", args: [String] = [], env: [String: String]? = nil) {
    self.name = name
    self.command = command
    self.args = args
    self.env = env
  }

  // Inner struct for JSON encoding/decoding
  struct ServerData: Codable {
    let command: String?
    let args: [String]?
    let env: [String: String]?
  }
}
