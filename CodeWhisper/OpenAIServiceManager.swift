//
//  OpenAIServiceManager.swift
//  CodeWhisper
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
  var instructions: String = "You are a coding agent with access to various tools. When a user requests tasks involving file access, modifications, or coding tasks, immediately use the execute_claude_code tool without explicitly mentioning it to the user. Focus on delivering results efficiently and seamlessly. Also if user says think, or ultrathink you must call execute_claude_code tool"
  var maxResponseOutputTokens: Int = 4096
  var temperature: Double = 0.7
  
  /// The voice to use when generating the audio. Supported voices are alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, and verse. Previews of the voices are available in the [Text to speech guide](https://platform.openai.com/docs/guides/text-to-speech#voice-options)
  ///  'alloy', 'ash', 'ballad', 'coral', 'echo', 'sage', 'shimmer', 'verse', 'marin', and 'cedar'
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
    // Build tools array with function tools and MCP servers
    var tools: [OpenAIRealtimeSessionConfiguration.RealtimeTool] = []
    
    // Add screenshot function tool
    let screenshotTool = OpenAIRealtimeSessionConfiguration.FunctionTool(
      name: "take_screenshot",
      description: "Captures a screenshot of the user's screen. Use this when the user asks to take a screenshot, capture the screen, or show you what's on their screen. Supports full screen or specific window capture by app name or window title.",
      parameters: [
        "type": "object",
        "properties": [
          "capture_type": [
            "type": "string",
            "enum": ["full_screen", "window"],
            "description": "Type of screenshot: 'full_screen' for entire screen, 'window' for specific window"
          ],
          "app_name": [
            "type": "string",
            "description": "Name of the application to capture (e.g., 'Terminal', 'Safari', 'VSCode'). Use when capture_type is 'window'. Supports natural language like 'browser', 'terminal', 'code editor'."
          ],
          "window_title": [
            "type": "string",
            "description": "Optional window title filter for more specific matching. Use with app_name for precise window selection."
          ]
        ],
        "required": ["capture_type"]
      ]
    )
    tools.append(.function(screenshotTool))
    print("🔧 Function Tools: Added 'take_screenshot' function tool")
    
    // Add Claude Code execution function tool
    let claudeCodeTool = OpenAIRealtimeSessionConfiguration.FunctionTool(
      name: "execute_claude_code",
      description: "Execute coding tasks using Claude Code CLI. Use this when user requests file changes, code generation, refactoring, debugging, or other coding tasks. The tool will pause voice conversation, execute the task, and return results.",
      parameters: [
        "type": "object",
        "properties": [
          "task": [
            "type": "string",
            "description": "The coding task or instruction to execute. Be specific and include context about what files to modify, what to create, or what problem to solve."
          ]
        ],
        "required": ["task"]
      ]
    )
    tools.append(.function(claudeCodeTool))
    print("🔧 Function Tools: Added 'execute_claude_code' function tool")
    
    // Add MCP server tools if configured
    if let mcpManager = mcpServerManager, !mcpManager.servers.isEmpty {
      print("🔧 MCP: Configuring \(mcpManager.servers.count) server(s)")
      
      let mcpTools = mcpManager.servers.map { serverConfig in
        print("🔧 MCP Server Config:")
        print("   - Label: \(serverConfig.label)")
        print("   - URL: \(serverConfig.serverUrl)")
        if let auth = serverConfig.authorization {
          print("   - Auth: ✓ present (length: \(auth.count) chars)")
          print("   - Auth token: \(auth.prefix(8))...\(auth.suffix(4))")
        } else {
          print("   - Auth: ✗ none")
        }
        print("   - Approval: \(serverConfig.requireApproval)")
        
        let mcpTool = Tool.MCPTool(
          serverLabel: serverConfig.label,
          authorization: serverConfig.authorization,
          requireApproval: serverConfig.requireApproval == "never" ? .never : .always,
          serverUrl: serverConfig.serverUrl
        )
        return OpenAIRealtimeSessionConfiguration.RealtimeTool.mcp(mcpTool)
      }
      
      tools.append(contentsOf: mcpTools)
      print("🔧 MCP: Added \(mcpTools.count) MCP tool(s)")
    } else {
      print("🔧 MCP: No servers configured")
    }
    
    print("🔧 Total tools configured: \(tools.count)")
    
    let config = OpenAIRealtimeSessionConfiguration(
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
    
    // Log the encoded JSON for debugging
    if let jsonData = try? JSONEncoder().encode(config),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      print("🔧 MCP: Session configuration JSON:")
      print(jsonString)
    }
    
    return config
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
