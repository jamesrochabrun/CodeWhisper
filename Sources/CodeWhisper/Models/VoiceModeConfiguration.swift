//
//  VoiceModeConfiguration.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import Foundation

// MARK: - VoiceMode

/// Defines the voice mode operation type for InlineVoiceModeView
public enum VoiceMode: Equatable, Sendable {
  /// Speech-to-text only - tap to toggle recording, outputs transcription
  case stt
  /// Text-to-speech only - uses Apple's AVSpeechSynthesizer
  case tts
  /// Combined STT + TTS - user speaks (STT), callback fires, parent triggers TTS for response
  case sttWithTTS
  /// Bidirectional realtime voice (current behavior)
  case realtime
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
