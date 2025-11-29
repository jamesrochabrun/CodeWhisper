//
//  OpenAIServiceManager.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/13/25.
//

import Foundation
import SwiftOpenAI
import os

/// Manages OpenAI service and realtime session configuration
@Observable
@MainActor
public final class OpenAIServiceManager {
  // MARK: - Service
  
  private(set) var service: OpenAIService?
  private var currentApiKey: String = ""
  
  // MCP Server Manager
  private var mcpServerManager: MCPServerManager?
  
  public init() {}
  
  // MARK: - Configuration Properties
  
  // Model and transcription
  public var transcriptionModel: String = "whisper-1"
  
  // Conversation settings
  public var instructions: String = """
You are a focused coding assistant that prioritizes execution over explanation.

## Core Behavior
- Start each session with a brief greeting, then listen for the user's requirements
- Keep responses concise and action-oriented
- Gather context proactively when needed to provide better assistance

## Available Tools

### Screenshot Tool (take_screenshot)
**Use when:**
- User explicitly requests to see their screen
- You need context about their current workspace (open files, IDE state, code)
- Beginning a session where visual context would help (use silently/proactively)

**Detection strategy:**
- Full screen: For general workspace context
- Specific windows: For focused tasks (target code editors, browsers, terminals)

**Note:** Screen context may not always be relevant—evaluate before acting on it.

### Claude Code Tool (execute_claude_code)
**Use for:**
- File operations (reading, creating, modifying)
- Code implementation and refactoring
- Debugging and error analysis
- Any task requiring file system access

**Triggers:** Execute immediately when user says "think" or "ultrathink" or for any task that involves file system or coding

## Execution Philosophy
Be proactive, not reactive. Gather what you need, then deliver results efficiently.

"""
  public var maxResponseOutputTokens: Int = 4096
  public var temperature: Double = 0.7
  
  /// The voice to use when generating the audio. Supported voices are alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, and verse. Previews of the voices are available in the [Text to speech guide](https://platform.openai.com/docs/guides/text-to-speech#voice-options)
  ///  'alloy', 'ash', 'ballad', 'coral', 'echo', 'sage', 'shimmer', 'verse', 'marin', and 'cedar'
  public var voice: String = "shimmer"
  
  // Turn detection
  public var turnDetectionEagerness: TurnDetectionEagerness = .medium
  
  // MARK: - Computed Properties
  
  public var hasValidService: Bool {
    service != nil
  }
  
  // MARK: - Service Management
  
  /// Updates the OpenAI service with a new API key
  /// Only recreates the service if the API key has actually changed
  public func updateService(apiKey: String) {
    let cleanApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Only recreate service if API key actually changed
    guard cleanApiKey != currentApiKey else {
      return
    }
    
    currentApiKey = cleanApiKey
    
    if cleanApiKey.isEmpty {
      service = nil
    } else {
      service = OpenAIServiceFactory.service(apiKey: cleanApiKey, debugEnabled: true)
    }
  }
  
  // MARK: - MCP Server Management
  
  public func setMCPServerManager(_ manager: MCPServerManager) {
    self.mcpServerManager = manager
  }
  
  public func mcpServersDidChange() {
    // Trigger configuration refresh if needed
    // For now, the configuration will be recreated on next session start
  }
  
  // MARK: - Configuration Generation
  
  /// Creates an OpenAI Realtime Session Configuration from current settings
  public func createSessionConfiguration() -> OpenAIRealtimeSessionConfiguration {
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
    
    // Add MCP server tools if configured
    if let mcpManager = mcpServerManager, !mcpManager.servers.isEmpty {
      let mcpTools = mcpManager.servers.map { serverConfig in
        let mcpTool = Tool.MCPTool(
          serverLabel: serverConfig.label,
          authorization: serverConfig.authorization,
          requireApproval: serverConfig.requireApproval == "never" ? .never : .always,
          serverUrl: serverConfig.serverUrl
        )
        return OpenAIRealtimeSessionConfiguration.RealtimeTool.mcp(mcpTool)
      }
      
      tools.append(contentsOf: mcpTools)
    }
    
    AppLogger.info("Tools configured: \(tools.count)")
    
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
    
    return config
  }
}

// MARK: - Supporting Types

extension OpenAIServiceManager {
  public enum TurnDetectionEagerness: String, CaseIterable {
    case low
    case medium
    case high
  }
}
