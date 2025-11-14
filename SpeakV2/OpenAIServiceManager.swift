//
//  OpenAIServiceManager.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/13/25.
//

import Foundation
import SwiftOpenAI

/// Manages OpenAI service and realtime session configuration
@Observable
@MainActor
final class OpenAIServiceManager {
  // MARK: - Service

  private(set) var service: OpenAIService?
  private var currentApiKey: String = ""

  // MCP Server Manager
  private var mcpServerManager: MCPServerManager?

  // MARK: - Configuration Properties

  // Model and transcription
  var transcriptionModel: String = "whisper-1"

  // Conversation settings
  var instructions: String = "You are a helpful AI assistant. Have a natural conversation with the user."
  var maxResponseOutputTokens: Int = 4096
  var temperature: Double = 0.7
  var voice: String = "alloy"

  // Turn detection
  var turnDetectionEagerness: TurnDetectionEagerness = .medium
  
  // MARK: - Computed Properties
  
  var hasValidService: Bool {
    service != nil
  }
  
  // MARK: - Service Management
  
  /// Updates the OpenAI service with a new API key
  /// Only recreates the service if the API key has actually changed
  func updateService(apiKey: String) {
    let cleanApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Only recreate service if API key actually changed
    guard cleanApiKey != currentApiKey else { return }
    
    currentApiKey = cleanApiKey
    
    if cleanApiKey.isEmpty {
      service = nil
    } else {
      service = OpenAIServiceFactory.service(apiKey: cleanApiKey)
    }
  }
  
  // MARK: - MCP Server Management

  func setMCPServerManager(_ manager: MCPServerManager) {
    self.mcpServerManager = manager
  }

  func mcpServersDidChange() {
    // Trigger configuration refresh if needed
    // For now, the configuration will be recreated on next session start
  }

  // MARK: - Configuration Generation

  /// Creates an OpenAI Realtime Session Configuration from current settings
  func createSessionConfiguration() -> OpenAIRealtimeSessionConfiguration {
    // Build tools array with MCP servers if configured
    var tools: [OpenAIRealtimeSessionConfiguration.RealtimeTool]? = nil

    if let mcpManager = mcpServerManager, !mcpManager.servers.isEmpty {
      tools = mcpManager.servers.map { serverConfig in
        let mcpTool = Tool.MCPTool(
          serverLabel: serverConfig.label,
          authorization: serverConfig.authorization,
          requireApproval: serverConfig.requireApproval == "never" ? .never : .always,
          serverUrl: serverConfig.serverUrl
        )
        return .mcp(mcpTool)
      }
    }

    return OpenAIRealtimeSessionConfiguration(
      inputAudioFormat: .pcm16,
      inputAudioTranscription: .init(model: transcriptionModel),
      instructions: instructions,
      maxResponseOutputTokens: .int(maxResponseOutputTokens),
      modalities: [.audio, .text],
      outputAudioFormat: .pcm16,
      temperature: temperature,
      tools: tools,
      turnDetection: .init(type: turnDetectionEagerness == .medium ? .semanticVAD(eagerness: .medium) : (turnDetectionEagerness == .low ? .semanticVAD(eagerness: .low) : .semanticVAD(eagerness: .high))),
      voice: voice
    )
  }
}

// MARK: - Supporting Types

extension OpenAIServiceManager {
  enum TurnDetectionEagerness: String, CaseIterable {
    case low
    case medium
    case high
  }
}
