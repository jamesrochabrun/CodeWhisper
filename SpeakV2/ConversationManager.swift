//
//  ConversationManager.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import Foundation
import Observation
import SwiftOpenAI
import AVFoundation

// Actor to safely share state between MainActor and RealtimeActor
actor ReadyState {
  var isReady = false
  
  func setReady(_ value: Bool) {
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

/// Represents a single message in the conversation
struct ConversationMessage: Identifiable {
  let id = UUID()
  let text: String
  let isUser: Bool
  let timestamp: Date
  let imageBase64URL: String? // Optional base64 data URL for images

  init(text: String, isUser: Bool, timestamp: Date, imageBase64URL: String? = nil) {
    self.text = text
    self.isUser = isUser
    self.timestamp = timestamp
    self.imageBase64URL = imageBase64URL
  }
}

@Observable
@MainActor
final class ConversationManager {
  // Connection state
  private(set) var isConnected = false
  private(set) var isListening = false
  private(set) var errorMessage: String?
  
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

  func startConversation(
    service: OpenAIService,
    configuration: OpenAIRealtimeSessionConfiguration
  ) async {
    do {
      print("ConversationManager.startConversation - Starting...")

      // Request microphone permission
      let permissionGranted = await requestMicrophonePermission()
      guard permissionGranted else {
        errorMessage = "Microphone permission is required for voice mode"
        return
      }

      // Create realtime session and audio controller on RealtimeActor
      print("Creating realtime session...")
      
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
      print("Starting microphone stream...")
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
            
            // Send audio to OpenAI
            if await readyState.isReady,
               let base64Audio = AudioUtils.base64EncodeAudioPCMBuffer(from: buffer) {
              await session.sendMessage(
                OpenAIRealtimeInputAudioBufferAppend(audio: base64Audio)
              )
            }
          }
        } catch {
          print("Microphone stream error: \(error)")
          await MainActor.run {
            self.errorMessage = "Microphone error: \(error.localizedDescription)"
          }
        }
      }
      
      // Handle session messages
      print("Starting session message handler...")
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
      
      print("ConversationManager: Successfully started conversation")
      
    } catch {
      errorMessage = "Failed to start conversation: \(error.localizedDescription)"
      isConnected = false
      print("ConversationManager error: \(error)")
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
      print("Realtime API Error: \(error ?? "Unknown error")")
      await MainActor.run {
        self.errorMessage = error ?? "Unknown error"
      }
      session.disconnect()
      
    case .sessionUpdated:
      print("Session updated - OpenAI is ready")
      await MainActor.run {
        self.conversationState = .idle
      }
      // Optionally start AI speaking first
      await session.sendMessage(OpenAIRealtimeResponseCreate())
      
    case .responseCreated:
      print("Response created - AI is thinking")
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
      print("User started speaking - interrupting playback")
      audioController.interruptPlayback()
      await MainActor.run {
        self.conversationState = .userSpeaking
      }
      
    case .responseTranscriptDone(let transcript):
      print("AI: \(transcript)")
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
      print("User: \(transcript)")
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
      print("Function call: \(name)(\(args)) - callId: \(callId)")
      // Handle function calls here if needed
      
    case .sessionCreated:
      print("Session created")
      
    case .responseTranscriptDelta(let delta):
      print("AI transcript delta: \(delta)")
      
    case .inputAudioBufferTranscript(let transcript):
      print("Input audio transcript: \(transcript)")

    case .inputAudioTranscriptionDelta(let delta):
      print("User transcript delta: \(delta)")

    // MCP (Model Context Protocol) message handling
    case .mcpListToolsInProgress:
      print("🔧 MCP: Tool discovery in progress...")

    case .mcpListToolsCompleted(let tools):
      print("✅ MCP: Tool discovery completed successfully")
      print("🔧 MCP: Available tools: \(tools)")

    case .mcpListToolsFailed(let error):
      print("❌ MCP: Tool discovery FAILED")
      print("❌ MCP Error: \(error ?? "Unknown error")")
      await MainActor.run {
        self.errorMessage = "MCP Error: \(error ?? "Unknown error")"
      }
    }
  }
  
  /// Send an image with optional text to the conversation
  func sendImage(_ imageBase64URL: String, text: String = "What do you see in this image?") async {
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

      print("Image sent successfully with text: \(text)")

    } catch {
      errorMessage = "Failed to send image: \(error.localizedDescription)"
      print("Error sending image: \(error)")
    }
  }

  func stopConversation() {
    print("ConversationManager.stopConversation - Stopping...")

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
    
    print("ConversationManager: Conversation stopped")
  }
  
  private func requestMicrophonePermission() async -> Bool {
    print("Checking microphone permission...")
    
#if os(macOS)
    let currentPermission = await AVAudioApplication.shared.recordPermission
    print("Current permission: \(currentPermission.rawValue)")
    
    if currentPermission == .granted {
      print("Microphone permission: already granted")
      return true
    }
    
    print("Requesting microphone permission...")
    let granted = await AVAudioApplication.requestRecordPermission()
    print("Microphone permission: \(granted ? "granted" : "denied")")
    return granted
#else
    // iOS uses AVAudioSession
    switch AVAudioSession.sharedInstance().recordPermission {
    case .granted:
      print("Microphone permission: already granted")
      return true
    case .denied:
      print("Microphone permission: denied")
      return false
    case .undetermined:
      print("Requesting microphone permission...")
      return await withCheckedContinuation { continuation in
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          print("Microphone permission: \(granted ? "granted" : "denied")")
          continuation.resume(returning: granted)
        }
      }
    @unknown default:
      return false
    }
#endif
  }
}
