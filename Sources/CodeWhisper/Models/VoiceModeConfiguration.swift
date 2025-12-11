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

// MARK: - RealtimeLanguage

/// Language option for Realtime API transcription and AI spoken responses
public enum RealtimeLanguage: Equatable, Sendable {
  case auto
  case english
  case spanish
  case french
  case japanese
  case chinese
  case hindi
  case german
  case portuguese
  case italian
  case korean
  case russian
  case custom(String)

  /// ISO-639-1 language code, or nil for auto-detect
  public var code: String? {
    switch self {
    case .auto: return nil
    case .english: return "en"
    case .spanish: return "es"
    case .french: return "fr"
    case .japanese: return "ja"
    case .chinese: return "zh"
    case .hindi: return "hi"
    case .german: return "de"
    case .portuguese: return "pt"
    case .italian: return "it"
    case .korean: return "ko"
    case .russian: return "ru"
    case .custom(let code): return code.isEmpty ? nil : code
    }
  }

  /// Display name for UI
  public var displayName: String {
    switch self {
    case .auto: return "Auto-detect"
    case .english: return "English"
    case .spanish: return "Spanish"
    case .french: return "French"
    case .japanese: return "Japanese"
    case .chinese: return "Chinese"
    case .hindi: return "Hindi"
    case .german: return "German"
    case .portuguese: return "Portuguese"
    case .italian: return "Italian"
    case .korean: return "Korean"
    case .russian: return "Russian"
    case .custom(let code): return code.isEmpty ? "Custom" : "Custom (\(code))"
    }
  }

  /// Raw value for persistence
  public var rawValue: String {
    switch self {
    case .auto: return "auto"
    case .english: return "en"
    case .spanish: return "es"
    case .french: return "fr"
    case .japanese: return "ja"
    case .chinese: return "zh"
    case .hindi: return "hi"
    case .german: return "de"
    case .portuguese: return "pt"
    case .italian: return "it"
    case .korean: return "ko"
    case .russian: return "ru"
    case .custom(let code): return code
    }
  }

  /// Initialize from raw value
  public init?(rawValue: String) {
    switch rawValue {
    case "auto": self = .auto
    case "en": self = .english
    case "es": self = .spanish
    case "fr": self = .french
    case "ja": self = .japanese
    case "zh": self = .chinese
    case "hi": self = .hindi
    case "de": self = .german
    case "pt": self = .portuguese
    case "it": self = .italian
    case "ko": self = .korean
    case "ru": self = .russian
    default: return nil  // Let caller handle custom values
    }
  }

  /// All preset cases (excluding custom)
  public static var presets: [RealtimeLanguage] {
    [.auto, .english, .spanish, .french, .german, .italian, .portuguese, .japanese, .chinese, .korean, .hindi, .russian]
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
