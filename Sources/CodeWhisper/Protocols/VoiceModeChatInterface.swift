//
//  VoiceModeChatInterface.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/29/25.
//

import Combine
import Foundation

// MARK: - VoiceModeMessage

/// Represents a simplified message for voice mode consumption
public struct VoiceModeMessage: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let role: VoiceModeMessageRole
  public let content: String
  public let isComplete: Bool
  public let timestamp: Date

  public init(
    id: UUID,
    role: VoiceModeMessageRole,
    content: String,
    isComplete: Bool,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.isComplete = isComplete
    self.timestamp = timestamp
  }
}

/// Role of the message sender for voice mode
public enum VoiceModeMessageRole: Sendable {
  case user
  case assistant
  case system
}

// MARK: - VoiceModeChatInterface Protocol

/// Protocol for voice mode to interact with chat systems
/// Uses Publisher/Callback pattern for loose coupling
@MainActor
public protocol VoiceModeChatInterface: AnyObject {

  // MARK: - State Publishers

  /// Publisher that emits when a new assistant message completes
  /// - Returns: Publisher that emits VoiceModeMessage when assistant response is complete
  var assistantMessageCompletedPublisher: AnyPublisher<VoiceModeMessage, Never> { get }

  /// Publisher that emits execution state changes
  var isExecutingPublisher: AnyPublisher<Bool, Never> { get }

  // MARK: - Current State (read-only)

  /// Whether the system is currently processing a request
  var isExecuting: Bool { get }

  /// Current working directory for context
  var workingDirectory: String? { get }

  // MARK: - Actions

  /// Send a transcribed message from voice input
  /// - Parameter text: The transcribed text to send
  func sendVoiceMessage(_ text: String)

  /// Cancel the current execution
  func cancelExecution()
}

// MARK: - Default Implementations

public extension VoiceModeChatInterface {
  /// Convenience method to check if ready for voice input
  var isReadyForVoiceInput: Bool {
    !isExecuting
  }
}

// MARK: - Configuration

/// Configuration for voice mode behavior
public struct VoiceModeInterfaceConfiguration {
  /// Delay before triggering TTS after message completion
  public var ttsDelayAfterCompletion: TimeInterval

  /// Whether to auto-trigger TTS on assistant message completion
  public var autoTriggerTTS: Bool

  public init(
    ttsDelayAfterCompletion: TimeInterval = 0.1,
    autoTriggerTTS: Bool = true
  ) {
    self.ttsDelayAfterCompletion = ttsDelayAfterCompletion
    self.autoTriggerTTS = autoTriggerTTS
  }

  public static let `default` = VoiceModeInterfaceConfiguration()
}
