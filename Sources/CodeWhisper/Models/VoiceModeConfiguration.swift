//
//  VoiceModeConfiguration.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import Foundation

// MARK: - VoiceMode

/// Defines the voice mode operation type for InlineVoiceModeView
public enum VoiceMode: String, Equatable, Sendable, CaseIterable, Codable {
  /// Speech-to-text only - tap to toggle recording, outputs transcription
  case stt = "stt"
  /// Combined STT + TTS - user speaks (STT), callback fires, parent triggers TTS for response
  case sttWithTTS = "stt_with_tts"
  /// Bidirectional realtime voice (current behavior)
  case realtime = "realtime"

  /// Display name for UI
  public var displayName: String {
    switch self {
    case .stt:
      return "Speech to Text"
    case .sttWithTTS:
      return "Voice Chat"
    case .realtime:
      return "Realtime Voice"
    }
  }

  /// Description for UI
  public var description: String {
    switch self {
    case .stt:
      return "Tap to record, transcribes to text"
    case .sttWithTTS:
      return "Speak and hear responses"
    case .realtime:
      return "Full bidirectional conversation"
    }
  }

  /// SF Symbol icon name
  public var iconName: String {
    switch self {
    case .stt:
      return "mic.fill"
    case .sttWithTTS:
      return "message.and.waveform.fill"
    case .realtime:
      return "waveform.circle.fill"
    }
  }
}

// MARK: - STTRecordingState

/// Recording state for STT mode
public enum STTRecordingState: Equatable, Sendable {
  case idle
  case recording
  case transcribing
  case error(String)
  
  public var isRecording: Bool {
    if case .recording = self { return true }
    return false
  }
  
  public var isTranscribing: Bool {
    if case .transcribing = self { return true }
    return false
  }
  
  public var isIdle: Bool {
    if case .idle = self { return true }
    return false
  }
}

// MARK: - TTSSpeakingState

/// Speaking state for TTS mode
public enum TTSSpeakingState: Equatable, Sendable {
  case idle
  case speaking
  case paused

  public var isSpeaking: Bool {
    if case .speaking = self { return true }
    return false
  }
}

// MARK: - CodeWhisperConfiguration

/// Configuration for CodeWhisperButton to specify available voice modes
public struct CodeWhisperConfiguration: Sendable {
  /// Voice modes available for selection. Order determines display order.
  public let availableVoiceModes: [VoiceMode]

  /// Default voice mode (first in availableVoiceModes)
  public var defaultVoiceMode: VoiceMode {
    availableVoiceModes.first ?? .stt
  }

  /// Whether to show the voice mode picker (hidden if only 1 mode)
  public var showVoiceModePicker: Bool {
    availableVoiceModes.count > 1
  }

  public init(availableVoiceModes: [VoiceMode] = VoiceMode.allCases) {
    // Ensure at least one mode, default to all if empty
    self.availableVoiceModes = availableVoiceModes.isEmpty
      ? Array(VoiceMode.allCases)
      : availableVoiceModes
  }

  /// All voice modes available (default)
  public static let all = CodeWhisperConfiguration()

  /// Speech-to-text only
  public static let sttOnly = CodeWhisperConfiguration(availableVoiceModes: [.stt])

  /// Voice chat only (STT + TTS)
  public static let voiceChatOnly = CodeWhisperConfiguration(availableVoiceModes: [.sttWithTTS])

  /// Realtime voice only
  public static let realtimeOnly = CodeWhisperConfiguration(availableVoiceModes: [.realtime])

  /// All modes except realtime
  public static let noRealtime = CodeWhisperConfiguration(availableVoiceModes: [.stt, .sttWithTTS])
}
