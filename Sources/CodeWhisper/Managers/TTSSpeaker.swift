//
//  TTSSpeaker.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import Foundation
import Observation
import AVFoundation
import SwiftOpenAI

/// Text-to-speech manager that supports multiple backends.
/// Provides a unified API for speaking text with progress tracking for visualization.
@Observable
@MainActor
public final class TTSSpeaker: NSObject, TTSBackendDelegate {

  // MARK: - Public State

  /// Current speaking state
  public private(set) var state: TTSSpeakingState = .idle

  /// Speaking progress (0.0 - 1.0) for visualization
  public private(set) var speakingProgress: Float = 0.0

  /// Audio level for visualizer
  public private(set) var audioLevel: Float = 0.0

  // MARK: - Configuration

  /// TTS configuration (provider, voice settings, etc.)
  public var configuration: TTSConfiguration {
    didSet {
      updateBackendConfigurations()
    }
  }

  // MARK: - Private Properties

  private let appleBackend: AppleTTSBackend
  private let openAIBackend: OpenAITTSBackend
  private var openAIService: OpenAIService?

  // MARK: - Initialization

  public override init() {
    self.configuration = .default
    self.appleBackend = AppleTTSBackend()
    self.openAIBackend = OpenAITTSBackend()
    super.init()
    appleBackend.delegate = self
    openAIBackend.delegate = self
  }

  public init(configuration: TTSConfiguration) {
    self.configuration = configuration
    self.appleBackend = AppleTTSBackend()
    self.openAIBackend = OpenAITTSBackend()
    super.init()
    appleBackend.delegate = self
    openAIBackend.delegate = self
  }

  // MARK: - Service Configuration

  /// Configure the OpenAI service for remote TTS
  public func configure(service: OpenAIService) {
    self.openAIService = service
    openAIBackend.configure(service: service)
  }

  // MARK: - Public Methods

  /// Speak the given text using the configured provider
  public func speak(text: String) {
    print("[TTSSpeaker] speak() called, provider: \(configuration.provider)")

    switch configuration.provider {
    case .apple:
      appleBackend.updateConfiguration(configuration)
      appleBackend.speak(text: text)

    case .openAI:
      guard openAIService != nil else {
        print("[TTSSpeaker] OpenAI service not configured, falling back to Apple")
        appleBackend.updateConfiguration(configuration)
        appleBackend.speak(text: text)
        return
      }
      openAIBackend.updateConfiguration(configuration)
      Task {
        await openAIBackend.speak(text: text)
      }
    }
  }

  /// Stop speaking immediately
  public func stop() {
    appleBackend.stop()
    openAIBackend.stop()
    state = .idle
    speakingProgress = 0.0
    audioLevel = 0.0
  }

  /// Pause speaking
  public func pause() {
    switch configuration.provider {
    case .apple:
      appleBackend.pause()
    case .openAI:
      openAIBackend.pause()
    }
  }

  /// Resume speaking after pause
  public func resume() {
    switch configuration.provider {
    case .apple:
      appleBackend.resume()
    case .openAI:
      openAIBackend.resume()
    }
  }

  // MARK: - Private Methods

  private func updateBackendConfigurations() {
    appleBackend.updateConfiguration(configuration)
    openAIBackend.updateConfiguration(configuration)
  }

  // MARK: - TTSBackendDelegate

  public func ttsBackendDidStartSpeaking() {
    state = .speaking
    speakingProgress = 0.0
  }

  public func ttsBackendDidFinishSpeaking() {
    state = .idle
    speakingProgress = 1.0
    audioLevel = 0.0
  }

  public func ttsBackendDidCancel() {
    state = .idle
    speakingProgress = 0.0
    audioLevel = 0.0
  }

  public func ttsBackendDidPause() {
    state = .paused
  }

  public func ttsBackendDidResume() {
    state = .speaking
  }

  public func ttsBackendDidUpdateProgress(_ progress: Float) {
    speakingProgress = progress
  }

  public func ttsBackendDidUpdateAudioLevel(_ level: Float) {
    audioLevel = level
  }
}
