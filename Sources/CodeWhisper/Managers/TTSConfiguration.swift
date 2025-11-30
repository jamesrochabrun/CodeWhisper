//
//  TTSConfiguration.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/29/25.
//

import Foundation
import SwiftOpenAI

// MARK: - TTS Provider

/// Available TTS providers
public enum TTSProvider: String, CaseIterable, Codable {
  case apple   // Local AVSpeechSynthesizer
  case openAI  // Remote OpenAI TTS API

  public var displayName: String {
    switch self {
    case .apple: return "Apple (Local)"
    case .openAI: return "OpenAI (Remote)"
    }
  }

  public var description: String {
    switch self {
    case .apple: return "Works offline, instant playback"
    case .openAI: return "Higher quality, natural voices"
    }
  }
}

// MARK: - OpenAI TTS Voice

/// OpenAI TTS voice options (mirrors AudioSpeechParameters.Voice)
public enum OpenAITTSVoice: String, CaseIterable, Codable {
  case alloy
  case echo
  case fable
  case onyx
  case nova
  case shimmer
  case ash
  case coral
  case sage

  public var displayName: String {
    rawValue.capitalized
  }

  /// Convert to SwiftOpenAI's Voice type
  public var audioSpeechVoice: AudioSpeechParameters.Voice {
    switch self {
    case .alloy: return .alloy
    case .echo: return .echo
    case .fable: return .fable
    case .onyx: return .onyx
    case .nova: return .nova
    case .shimmer: return .shimmer
    case .ash: return .ash
    case .coral: return .coral
    case .sage: return .sage
    }
  }
}

// MARK: - OpenAI TTS Model

/// OpenAI TTS model options
public enum OpenAITTSModel: String, CaseIterable, Codable {
  case tts1 = "tts-1"
  case tts1HD = "tts-1-hd"

  public var displayName: String {
    switch self {
    case .tts1: return "Standard (tts-1)"
    case .tts1HD: return "HD (tts-1-hd)"
    }
  }

  /// Convert to SwiftOpenAI's TTSModel type
  public var audioSpeechModel: AudioSpeechParameters.TTSModel {
    switch self {
    case .tts1: return .tts1
    case .tts1HD: return .tts1HD
    }
  }
}

// MARK: - TTS Configuration

/// Configuration for TTS settings
public struct TTSConfiguration: Codable, Equatable {

  // MARK: - Provider Selection

  /// The active TTS provider
  public var provider: TTSProvider

  // MARK: - Apple TTS Settings

  /// Apple voice identifier (e.g., "com.apple.voice.enhanced.en-US.Samantha")
  public var appleVoiceIdentifier: String?

  /// Apple speech rate (0.0 - 1.0, default 0.5)
  public var appleRate: Float

  /// Apple pitch multiplier (0.5 - 2.0, default 1.0)
  public var applePitch: Float

  // MARK: - OpenAI TTS Settings

  /// OpenAI TTS model
  public var openAIModel: OpenAITTSModel

  /// OpenAI TTS voice
  public var openAIVoice: OpenAITTSVoice

  /// OpenAI TTS speed (0.25 - 4.0, default 1.0)
  public var openAISpeed: Double

  // MARK: - Initialization

  public init(
    provider: TTSProvider = .openAI,
    appleVoiceIdentifier: String? = nil,
    appleRate: Float = 0.5,
    applePitch: Float = 1.0,
    openAIModel: OpenAITTSModel = .tts1,
    openAIVoice: OpenAITTSVoice = .nova,
    openAISpeed: Double = 1.0
  ) {
    self.provider = provider
    self.appleVoiceIdentifier = appleVoiceIdentifier
    self.appleRate = appleRate
    self.applePitch = applePitch
    self.openAIModel = openAIModel
    self.openAIVoice = openAIVoice
    self.openAISpeed = openAISpeed
  }

  /// Default configuration with OpenAI as the default provider
  public static let `default` = TTSConfiguration()
}
