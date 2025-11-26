//
//  ConversationManager.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import Foundation
import Observation
import SwiftOpenAI
import AVFoundation
import ScreenCaptureKit
import AppKit
import os

// Actor to safely share state between MainActor and RealtimeActor
actor ReadyState {
  public var isReady = false
  
  public func setReady(_ value: Bool) {
    isReady = value
  }
}

/// Represents the current state of the conversation
enum ConversationState: Int {
  case idle = 0           // No activity
  case userSpeaking = 1   // User is speaking
  case aiThinking = 2     // AI is processing/preparing response
  case aiSpeaking = 3     // AI is speaking
}

/// Represents the type of message in the conversation
public enum ConversationMessageType {
  case regular              // Normal user/AI message
  case claudeCodeStart      // Claude Code task started
  case claudeCodeProgress   // Claude Code progress update
  case claudeCodeResult     // Claude Code final result
  case claudeCodeError      // Claude Code error
}

/// Represents a single message in the conversation
public struct ConversationMessage: Identifiable {
  public let id = UUID()
  public let text: String
  public let isUser: Bool
  public let timestamp: Date
  public let imageBase64URL: String? // Optional base64 data URL for images
  public let messageType: ConversationMessageType // Type of message
  
  public init(
    text: String,
    isUser: Bool,
    timestamp: Date,
    imageBase64URL: String? = nil,
    messageType: ConversationMessageType = .regular
  ) {
    self.text = text
    self.isUser = isUser
    self.timestamp = timestamp
    self.imageBase64URL = imageBase64URL
    self.messageType = messageType
  }
}

@Observable
@MainActor
public final class ConversationManager {
  // Connection state
  private(set) var isConnected = false
  private(set) var isListening = false
  private(set) var errorMessage: String?
  private(set) var warningMessage: String?
  
  // Microphone mute state
  private(set) var isMicrophoneMuted = false

  // Tool execution state
  private(set) var isExecutingTool = false
  private var currentToolCallId: String?
  private var toolExecutionTask: Task<Void, Never>?
  
  // Audio levels and frequency data
  private(set) var audioLevel: Float = 0.0           // User mic RMS amplitude
  private(set) var aiAudioLevel: Float = 0.0         // AI speech RMS amplitude
  private(set) var lowFrequency: Float = 0.0         // Low frequency band (0-250Hz)
  private(set) var midFrequency: Float = 0.0         // Mid frequency band (250-2000Hz)
  private(set) var highFrequency: Float = 0.0        // High frequency band (2000Hz+)
  
  // Conversation state
  private(set) var conversationState: ConversationState = .idle
  
  // Conversation messages
  private(set) var messages: [ConversationMessage] = []
  
  // Screenshot capture
  private let screenshotCapture = ScreenshotCapture()

  // Last captured screenshot data (PNG) to pass to Claude Code
  private var lastCapturedScreenshot: Data?

  // Claude Code manager
  private var claudeCodeManager: ClaudeCodeManager?
  
  // Settings manager
  private var settingsManager: SettingsManager?
  
  // Smoothing for visual transitions
  private var smoothedAudioLevel: Float = 0.0
  private var smoothedAiAudioLevel: Float = 0.0
  private var smoothedLowFreq: Float = 0.0
  private var smoothedMidFreq: Float = 0.0
  private var smoothedHighFreq: Float = 0.0
  
  private var realtimeSession: OpenAIRealtimeSession?
  private var audioController: AudioController?
  private var sessionTask: Task<Void, Never>?
  private var micTask: Task<Void, Never>?
  
  // private let modelName = "gpt-4o-mini-realtime-preview-2024-12-17"
  private let modelName = "gpt-realtime"
  
  public func startConversation(
    service: OpenAIService,
    configuration: OpenAIRealtimeSessionConfiguration
  ) async {
    do {
      // Request microphone permission
      let permissionGranted = await requestMicrophonePermission()
      guard permissionGranted else {
        errorMessage = "Microphone permission is required for voice mode"
        return
      }

      // Create realtime session and audio controller on RealtimeActor
      
      // Capture the session and controller from RealtimeActor context
      let sessionAndController: (OpenAIRealtimeSession, AudioController) = try await Task { @RealtimeActor in
        let session = try await service.realtimeSession(
          model: modelName,
          configuration: configuration
        )
        let audioController = try await AudioController(modes: [.playback, .record])
        return (session, audioController)
      }.value
      
      let session = sessionAndController.0
      let audioController = sessionAndController.1
      
      self.realtimeSession = session
      self.audioController = audioController

      // Start streaming microphone to OpenAI
      let readyState = ReadyState()
      
      micTask = Task { @RealtimeActor in
        do {
          let micStream = try audioController.micStream()
          for await buffer in micStream {
            guard !Task.isCancelled else { break }
            
            // Analyze audio buffer for amplitude and frequency data
            let rms = AudioAnalyzer.calculateRMS(buffer: buffer)
            let frequencies = AudioAnalyzer.analyzeFrequencies(buffer: buffer)
            
            // Update UI on MainActor with smoothed values
            await MainActor.run {
              self.smoothedAudioLevel = AudioAnalyzer.smoothValue(
                self.smoothedAudioLevel,
                target: rms,
                smoothing: 0.7
              )
              self.audioLevel = self.smoothedAudioLevel
              
              self.smoothedLowFreq = AudioAnalyzer.smoothValue(
                self.smoothedLowFreq,
                target: frequencies.low,
                smoothing: 0.7
              )
              self.lowFrequency = self.smoothedLowFreq
              
              self.smoothedMidFreq = AudioAnalyzer.smoothValue(
                self.smoothedMidFreq,
                target: frequencies.mid,
                smoothing: 0.7
              )
              self.midFrequency = self.smoothedMidFreq
              
              self.smoothedHighFreq = AudioAnalyzer.smoothValue(
                self.smoothedHighFreq,
                target: frequencies.high,
                smoothing: 0.7
              )
              self.highFrequency = self.smoothedHighFreq
            }
            
            // Send audio to OpenAI (only if not muted)
            let isMuted = await MainActor.run { self.isMicrophoneMuted }
            if !isMuted,
               await readyState.isReady,
               let base64Audio = AudioUtils.base64EncodeAudioPCMBuffer(from: buffer) {
              await session.sendMessage(
                OpenAIRealtimeInputAudioBufferAppend(audio: base64Audio)
              )
            }
          }
        } catch {
          AppLogger.error("Microphone stream error: \(error.localizedDescription)")
          await MainActor.run {
            self.errorMessage = "Microphone error: \(error.localizedDescription)"
          }
        }
      }

      // Handle session messages
      sessionTask = Task { @RealtimeActor in
        for await message in session.receiver {
          guard !Task.isCancelled else { break }
          
          await self.handleRealtimeMessage(
            message,
            session: session,
            audioController: audioController,
            readyState: readyState
          )
        }
      }
      
      // Update connection state
      isConnected = true
      isListening = true

      AppLogger.info("Conversation started")

    } catch {
      errorMessage = "Failed to start conversation: \(error.localizedDescription)"
      isConnected = false
      AppLogger.error("Failed to start conversation: \(error.localizedDescription)")
    }
  }
  
  @RealtimeActor
  private func handleRealtimeMessage(
    _ message: OpenAIRealtimeMessage,
    session: OpenAIRealtimeSession,
    audioController: AudioController,
    readyState: ReadyState
  ) async {
    switch message {
    case .error(let error):
      AppLogger.error("Realtime API error: \(error ?? "Unknown error")")
      await MainActor.run {
        self.errorMessage = error ?? "Unknown error"
        self.isConnected = false
      }
      session.disconnect()

    case .sessionUpdated:
      await MainActor.run {
        self.conversationState = .idle
      }
      // Optionally start AI speaking first
      await session.sendMessage(OpenAIRealtimeResponseCreate())

    case .responseCreated:
      await readyState.setReady(true)
      await MainActor.run {
        self.conversationState = .aiThinking
      }
      
    case .responseAudioDelta(let base64Audio):
      // Analyze AI audio for amplitude
      let aiRms = AudioAnalyzer.calculateRMSFromBase64(base64String: base64Audio)
      
      // Update AI audio level with smoothing
      await MainActor.run {
        self.smoothedAiAudioLevel = AudioAnalyzer.smoothValue(
          self.smoothedAiAudioLevel,
          target: aiRms,
          smoothing: 0.7
        )
        self.aiAudioLevel = self.smoothedAiAudioLevel
        self.conversationState = .aiSpeaking
      }
      
      // Play audio chunk from AI
      audioController.playPCM16Audio(base64String: base64Audio)

    case .inputAudioBufferSpeechStarted:
      audioController.interruptPlayback()
      await MainActor.run {
        self.conversationState = .userSpeaking
      }

    case .responseTranscriptDone(let transcript):
      await MainActor.run {
        // Add AI message to conversation
        self.messages.append(ConversationMessage(
          text: transcript,
          isUser: false,
          timestamp: Date()
        ))
        
        // Fade out AI audio level
        self.aiAudioLevel = 0.0
        self.smoothedAiAudioLevel = 0.0
        if self.conversationState == .aiSpeaking {
          self.conversationState = .idle
        }
      }

    case .inputAudioTranscriptionCompleted(let transcript):
      await MainActor.run {
        // Add user message to conversation
        self.messages.append(ConversationMessage(
          text: transcript,
          isUser: true,
          timestamp: Date()
        ))
        
        if self.conversationState == .userSpeaking {
          self.conversationState = .idle
        }
      }

    case .responseFunctionCallArgumentsDone(let name, let args, let callId):
      await handleFunctionCall(name: name, arguments: args, callId: callId, session: session)

    case .sessionCreated:
      break

    case .responseTranscriptDelta:
      break

    case .inputAudioBufferTranscript:
      break

    case .inputAudioTranscriptionDelta:
      break

      // MCP (Model Context Protocol) message handling
    case .mcpListToolsInProgress:
      break

    case .mcpListToolsCompleted:
      AppLogger.info("MCP tool discovery completed")

    case .mcpListToolsFailed(let error):
      AppLogger.error("MCP tool discovery failed: \(error ?? "Unknown error")")
      await MainActor.run {
        self.errorMessage = "MCP Error: \(error ?? "Unknown error")"
      }
      
    case .responseDone(let status, let statusDetails):
      // Check for errors in the response
      if let statusDetails = statusDetails,
         let statusDetailsDict = statusDetails["status_details"] as? [String: Any],
         let error = statusDetailsDict["error"] as? [String: Any],
         let code = error["code"] as? String,
         let message = error["message"] as? String {

        AppLogger.error("Response failed: [\(code)] \(message)")

        // Set error message for UI display
        await MainActor.run {
          self.errorMessage = "\(code): \(message)"

          // Add error to conversation transcript
          self.messages.append(ConversationMessage(
            text: "Error: \(message)",
            isUser: false,
            timestamp: Date(),
            messageType: .regular
          ))
        }

        // Disconnect on critical errors
        if code == "insufficient_quota" || code == "invalid_api_key" {
          AppLogger.warning("Critical error detected, disconnecting session")
          await MainActor.run {
            self.isConnected = false
          }
          session.disconnect()
        }
      } else if status == "failed" {
        // Failed status but no detailed error information
        AppLogger.error("Response failed without detailed error information")
        await MainActor.run {
          self.errorMessage = "Response failed: \(status)"
        }
      }

    // Text streaming (text-only responses) - not used since primary focus is audio
    case .responseTextDelta:
      break

    case .responseTextDone:
      break

    // Output item lifecycle - not needed for current audio-focused implementation
    case .responseOutputItemAdded:
      break

    case .responseOutputItemDone:
      break

    // Content part lifecycle - not needed for current audio-focused implementation
    case .responseContentPartAdded:
      break

    case .responseContentPartDone:
      break

    // Conversation item creation - not needed for current implementation
    case .conversationItemCreated:
      break
    }
  }
  
  /// Send an image with optional text to the conversation
  public func sendImage(_ imageBase64URL: String, text: String = "") async {
    guard let session = realtimeSession else {
      errorMessage = "No active session"
      return
    }
    
    do {
      // Create conversation item with image and text
      let item = OpenAIRealtimeConversationItemCreate.Item(
        role: "user",
        content: [
          .image(imageBase64URL),
          .text(text)
        ]
      )
      
      // Send to session on RealtimeActor
      try await Task { @RealtimeActor in
        await session.sendMessage(
          OpenAIRealtimeConversationItemCreate(item: item)
        )
        
        // Trigger AI response
        await session.sendMessage(OpenAIRealtimeResponseCreate())
      }.value
      
      // Add to local message history
      messages.append(ConversationMessage(
        text: text,
        isUser: true,
        timestamp: Date(),
        imageBase64URL: imageBase64URL
      ))

    } catch {
      errorMessage = "Failed to send image: \(error.localizedDescription)"
      AppLogger.error("Failed to send image: \(error.localizedDescription)")
    }
  }
  
  /// Send a text message to the conversation
  public func sendText(_ text: String) async {
    guard let session = realtimeSession else {
      errorMessage = "No active session"
      return
    }
    
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }
    
    do {
      // Create conversation item with text only
      let item = OpenAIRealtimeConversationItemCreate.Item(
        role: "user",
        text: text
      )
      
      // Send to session on RealtimeActor
      try await Task { @RealtimeActor in
        await session.sendMessage(
          OpenAIRealtimeConversationItemCreate(item: item)
        )
        
        // Trigger AI response
        await session.sendMessage(OpenAIRealtimeResponseCreate())
      }.value
      
      // Add to local message history
      messages.append(ConversationMessage(
        text: text,
        isUser: true,
        timestamp: Date()
      ))

    } catch {
      errorMessage = "Failed to send text: \(error.localizedDescription)"
      AppLogger.error("Failed to send text: \(error.localizedDescription)")
    }
  }
  
  /// Send function call output back to OpenAI Realtime API
  private func sendFunctionCallOutput(callId: String, output: String, session: OpenAIRealtimeSession) async {
    do {
      // Create function call output using the custom struct
      let functionOutput = FunctionToolCallOutput(callId: callId, output: output)
      let itemCreateMessage = RealtimeConversationItemCreateWithFunctionOutput(item: functionOutput)

      // Send to session on RealtimeActor
      try await Task { @RealtimeActor in
        // Send the function output as a message
        await session.sendMessage(itemCreateMessage)

        // Trigger AI response so it speaks the result
        await session.sendMessage(OpenAIRealtimeResponseCreate())
      }.value

    } catch {
      AppLogger.error("Failed to send function call output: \(error.localizedDescription)")
    }
  }
  
  /// Custom struct to send function call output via conversation.item.create
  private struct RealtimeConversationItemCreateWithFunctionOutput: Encodable {
    let type = "conversation.item.create"
    let item: FunctionToolCallOutput
    
    init(item: FunctionToolCallOutput) {
      self.item = item
    }
  }
  
  /// Toggle microphone mute state
  public func toggleMicrophoneMute() {
    isMicrophoneMuted.toggle()
  }

  /// Cancel the current tool execution and send interrupted response to OpenAI
  public func cancelToolExecution() {
    guard isExecutingTool else {
      return
    }

    // Cancel the tool execution task
    toolExecutionTask?.cancel()
    toolExecutionTask = nil

    // Cancel Claude Code execution if running
    claudeCodeManager?.cancel()

    // Send interrupted response back to OpenAI if we have a callId
    if let callId = currentToolCallId, let session = realtimeSession {
      Task {
        await sendFunctionCallOutput(
          callId: callId,
          output: "Execution Interrupted by user",
          session: session
        )
      }
    }

    // Reset state
    isExecutingTool = false
    currentToolCallId = nil

    // Unmute microphone if it was muted for tool execution
    if isMicrophoneMuted {
      isMicrophoneMuted = false
    }

    // Add interrupted message to conversation
    messages.append(ConversationMessage(
      text: "Tool execution interrupted by user",
      isUser: false,
      timestamp: Date(),
      messageType: .claudeCodeError
    ))

    AppLogger.info("Tool execution cancelled")
  }

  /// Set settings manager for working directory configuration
  public func setSettingsManager(_ manager: SettingsManager) {
    self.settingsManager = manager
  }
  
  /// Initialize Claude Code manager with dependency injection
  /// The executor is created and configured by the calling application
  public func setClaudeCodeExecutor(_ executor: ClaudeCodeExecutor) {
    let manager = ClaudeCodeManager()
    manager.initialize(executor: executor)
    self.claudeCodeManager = manager
    AppLogger.info("Claude Code executor initialized")
  }

  /// Handle function/tool calls from the AI
  private func handleFunctionCall(name: String, arguments: String, callId: String, session: OpenAIRealtimeSession) async {
    switch name {
    case "take_screenshot":
      await handleScreenshotTool(arguments: arguments, callId: callId)

    case "execute_claude_code":
      await handleClaudeCodeTool(arguments: arguments, callId: callId, session: session)

    default:
      AppLogger.warning("Unknown function call: \(name)")
    }
  }
  
  /// Handle screenshot tool execution
  private func handleScreenshotTool(arguments: String, callId: String) async {
    // Parse arguments
    guard let args = parseScreenshotArguments(arguments) else {
      AppLogger.warning("Failed to parse screenshot arguments")
      return
    }
    
    // Determine capture type
    let captureType = args["capture_type"] as? String ?? "full_screen"
    
    if captureType == "window" {
      // Smart window selection
      let appName = args["app_name"] as? String
      let windowTitle = args["window_title"] as? String
      await captureSpecificWindow(appName: appName, windowTitle: windowTitle)
    } else {
      // Full screen capture (existing logic)
      await screenshotCapture.captureScreenshot()
    }
    
    // Check if capture was successful
    guard let capturedImage = screenshotCapture.capturedImage else {
      let error = screenshotCapture.errorMessage ?? "Screenshot capture failed"
      AppLogger.error("Screenshot capture failed: \(error)")
      await MainActor.run {
        self.warningMessage = error
      }
      return
    }

    // Convert to base64
    guard let base64URL = screenshotCapture.convertToBase64DataURL(capturedImage) else {
      AppLogger.error("Failed to convert screenshot to base64")
      await MainActor.run {
        self.warningMessage = "Failed to process screenshot"
      }
      return
    }

    // Store the screenshot data for Claude Code to use
    if let tiffData = capturedImage.tiffRepresentation,
       let bitmapImage = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
      lastCapturedScreenshot = pngData
    }
    
    // Send the screenshot as an image message
    let description = if captureType == "window", let app = args["app_name"] as? String {
      "I've captured a screenshot of \(app) as requested. Here's what's in the window:"
    } else {
      "I've captured a screenshot as requested. Here's what's on the screen:"
    }
    await sendImage(base64URL, text: description)
    
    // Clear the captured image
    screenshotCapture.clearImage()
  }
  
  /// Parse screenshot tool arguments
  private func parseScreenshotArguments(_ arguments: String) -> [String: Any]? {
    guard let data = arguments.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return json
  }
  
  /// Capture a specific window using smart matching
  private func captureSpecificWindow(appName: String?, windowTitle: String?) async {
    guard let appName = appName else {
      screenshotCapture.errorMessage = "app_name is required for window capture"
      return
    }
    
    do {
      // Get available windows
      let content = try await SCShareableContent.current
      
      // Apply same filtering as ScreenshotPickerView
      let availableWindows = content.windows.filter { window in
        guard window.owningApplication?.applicationName != "SpeakV2" else { return false }
        guard let title = window.title, !title.isEmpty else { return false }
        let minSize: CGFloat = 200
        guard window.frame.width >= minSize && window.frame.height >= minSize else { return false }
        guard window.isOnScreen else { return false }
        
        let systemApps = ["Window Server", "Dock", "SystemUIServer", "ControlCenter",
                          "Notification Center", "Spotlight", "Siri"]
        if let app = window.owningApplication?.applicationName, systemApps.contains(app) {
          return false
        }
        return true
      }
      
      // Use WindowMatcher to find best match
      guard let matchedWindow = WindowMatcher.findWindow(
        from: availableWindows,
        appName: appName,
        windowTitle: windowTitle
      ) else {
        let titleInfo = windowTitle.map { " with title '\($0)'" } ?? ""
        screenshotCapture.errorMessage = "No matching window found for app '\(appName)'\(titleInfo)"
        AppLogger.warning(screenshotCapture.errorMessage ?? "Window not found")
        return
      }

      // Capture the matched window
      await screenshotCapture.captureWindow(matchedWindow)

    } catch {
      screenshotCapture.errorMessage = "Failed to enumerate windows: \(error.localizedDescription)"
      AppLogger.error(screenshotCapture.errorMessage ?? "Window enumeration failed")
    }
  }
  
  /// Handle Claude Code tool execution
  private func handleClaudeCodeTool(arguments: String, callId: String, session: OpenAIRealtimeSession) async {
    // Parse arguments to extract task
    guard let task = parseClaudeCodeArguments(arguments) else {
      AppLogger.warning("Failed to parse Claude Code arguments")
      let errorMessage = "Error: Could not parse Claude Code task from arguments"
      messages.append(ConversationMessage(
        text: errorMessage,
        isUser: false,
        timestamp: Date(),
        messageType: .claudeCodeError
      ))

      // Send error result back to OpenAI
      await sendFunctionCallOutput(callId: callId, output: errorMessage, session: session)
      return
    }

    // Check if Claude Code is initialized
    guard let claudeCodeManager = claudeCodeManager else {
      AppLogger.error("Claude Code not initialized")
      let errorMessage = "Error: Claude Code is not initialized. Please configure your API key and working directory."
      messages.append(ConversationMessage(
        text: errorMessage,
        isUser: false,
        timestamp: Date(),
        messageType: .claudeCodeError
      ))
      
      // Send error result back to OpenAI
      await sendFunctionCallOutput(callId: callId, output: errorMessage, session: session)
      return
    }

    // Set tool execution state for cancellation support
    isExecutingTool = true
    currentToolCallId = callId

    // Pause voice mode (mute microphone)
    let wasMuted = isMicrophoneMuted
    if !wasMuted {
      isMicrophoneMuted = true
    }
    
    // Show Claude Code is processing
    messages.append(ConversationMessage(
      text: "\(task)",
      isUser: false,
      timestamp: Date(),
      messageType: .claudeCodeStart
    ))
    
    do {
      // Create TaskContext with screenshot if available
      var taskContext: TaskContext?
      if let screenshotData = lastCapturedScreenshot {
        let imageData = ImageData(data: screenshotData, mediaType: "image/png")
        taskContext = TaskContext(images: [imageData])
        // Clear the screenshot after use
        lastCapturedScreenshot = nil
      }

      // Start observing progress updates in parallel with execution
      let observationTask = Task {
        var lastProgressCount = 0

        while !Task.isCancelled {
          let currentProgressCount = claudeCodeManager.progressUpdates.count

          // Add new progress updates to conversation as they arrive
          if currentProgressCount > lastProgressCount {
            let newProgress = claudeCodeManager.progressUpdates[lastProgressCount...]

            await MainActor.run {
              for progress in newProgress {
                self.messages.append(ConversationMessage(
                  text: progress.content,
                  isUser: false,
                  timestamp: progress.timestamp,
                  messageType: .claudeCodeProgress
                ))
              }
            }

            lastProgressCount = currentProgressCount
          }

          // Check if execution is complete
          if claudeCodeManager.state == .completed || claudeCodeManager.state == .error("") {
            break
          }

          // Poll every 50ms for responsive updates
          try? await Task.sleep(for: .milliseconds(50))
        }
      }

      // Execute task with optional screenshot context (this blocks until complete)
      let result = try await claudeCodeManager.executeTask(task, context: taskContext)
      
      // Cancel observation task
      observationTask.cancel()

      // Check if cancelled during execution
      guard isExecutingTool else {
        return
      }

      // Process any remaining progress updates
      let processedCount = messages.filter({ $0.messageType == .claudeCodeProgress }).count
      let totalProgressCount = claudeCodeManager.progressUpdates.count

      if processedCount < totalProgressCount {
        let remainingProgress = claudeCodeManager.progressUpdates[processedCount...]
        for progress in remainingProgress {
          messages.append(ConversationMessage(
            text: progress.content,
            isUser: false,
            timestamp: progress.timestamp,
            messageType: .claudeCodeProgress
          ))
        }
      }
      
      // Add final result
      messages.append(ConversationMessage(
        text: result,
        isUser: false,
        timestamp: Date(),
        messageType: .claudeCodeResult
      ))

      AppLogger.info("Claude Code task completed")

      // Send result back to OpenAI so it can speak it
      await sendFunctionCallOutput(callId: callId, output: result, session: session)

    } catch {
      // Check if cancelled during execution
      guard isExecutingTool else {
        return
      }

      AppLogger.error("Claude Code task failed: \(error.localizedDescription)")
      let errorMessage = "Error Claude Code: \(error.localizedDescription)"
      messages.append(ConversationMessage(
        text: errorMessage,
        isUser: false,
        timestamp: Date(),
        messageType: .claudeCodeError
      ))

      // Send error result back to OpenAI
      await sendFunctionCallOutput(callId: callId, output: errorMessage, session: session)
    }

    // Reset tool execution state
    isExecutingTool = false
    currentToolCallId = nil

    // Resume voice mode (unmute if it wasn't muted before)
    if !wasMuted {
      isMicrophoneMuted = false
    }
  }
  
  /// Parse Claude Code arguments from JSON string
  private func parseClaudeCodeArguments(_ arguments: String) -> String? {
    guard let data = arguments.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let task = json["task"] as? String else {
      return nil
    }
    return task
  }
  
  public func clearError() {
    errorMessage = nil
  }
  
  public func clearWarning() {
    warningMessage = nil
  }
  
  public func stopConversation() {
    // Cancel tasks
    sessionTask?.cancel()
    micTask?.cancel()
    sessionTask = nil
    micTask = nil

    // Stop audio controller and disconnect session on RealtimeActor
    let audioController = self.audioController
    let realtimeSession = self.realtimeSession

    Task { @RealtimeActor in
      audioController?.stop()
      realtimeSession?.disconnect()
    }

    self.audioController = nil
    self.realtimeSession = nil

    // Reset all state
    isConnected = false
    isListening = false
    audioLevel = 0.0
    aiAudioLevel = 0.0
    lowFrequency = 0.0
    midFrequency = 0.0
    highFrequency = 0.0
    smoothedAudioLevel = 0.0
    smoothedAiAudioLevel = 0.0
    smoothedLowFreq = 0.0
    smoothedMidFreq = 0.0
    smoothedHighFreq = 0.0
    conversationState = .idle
    errorMessage = nil
    messages = []

    AppLogger.info("Conversation stopped")
  }
  
  private func requestMicrophonePermission() async -> Bool {
#if os(macOS)
    let currentPermission = await AVAudioApplication.shared.recordPermission

    if currentPermission == .granted {
      return true
    }

    return await AVAudioApplication.requestRecordPermission()
#else
    // iOS uses AVAudioSession
    switch AVAudioSession.sharedInstance().recordPermission {
    case .granted:
      return true
    case .denied:
      return false
    case .undetermined:
      return await withCheckedContinuation { continuation in
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          continuation.resume(returning: granted)
        }
      }
    @unknown default:
      return false
    }
#endif
  }
}
