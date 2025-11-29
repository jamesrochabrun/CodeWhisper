//
//  AppleTTSBackend.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/29/25.
//

import Foundation
import AVFoundation

/// Callback protocol for TTS backend state changes
@MainActor
public protocol TTSBackendDelegate: AnyObject {
  func ttsBackendDidStartSpeaking()
  func ttsBackendDidFinishSpeaking()
  func ttsBackendDidCancel()
  func ttsBackendDidPause()
  func ttsBackendDidResume()
  func ttsBackendDidUpdateProgress(_ progress: Float)
  func ttsBackendDidUpdateAudioLevel(_ level: Float)
}

/// Apple TTS backend using AVSpeechSynthesizer
@MainActor
public final class AppleTTSBackend: NSObject {

  // MARK: - Public Properties

  public weak var delegate: TTSBackendDelegate?

  // MARK: - Configuration

  /// The voice to use for speech synthesis
  public var voice: AVSpeechSynthesisVoice?

  /// Speech rate (0.0 - 1.0, where 0.5 is default)
  public var rate: Float = AVSpeechUtteranceDefaultSpeechRate

  /// Pitch multiplier (0.5 - 2.0, where 1.0 is default)
  public var pitch: Float = 1.0

  /// Volume (0.0 - 1.0)
  public var volume: Float = 1.0

  // MARK: - Private Properties

  private let synthesizer = AVSpeechSynthesizer()
  private var currentUtterance: AVSpeechUtterance?
  private var currentText: String = ""
  private var audioLevelTimer: Timer?

  // MARK: - Initialization

  public override init() {
    super.init()
    synthesizer.delegate = self

    // Set default voice (enhanced English voice if available)
    if let enhancedVoice = AVSpeechSynthesisVoice(language: "en-US") {
      voice = enhancedVoice
    }
  }

  // MARK: - Public Methods

  /// Speak the given text
  public func speak(text: String) {
    print("[AppleTTSBackend] speak() called with \(text.count) characters")

    // Stop any current speech
    stop()

    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      print("[AppleTTSBackend] Text is empty after trimming, skipping")
      return
    }

    currentText = text

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    utterance.rate = rate
    utterance.pitchMultiplier = pitch
    utterance.volume = volume

    currentUtterance = utterance

    // Start audio level simulation for visualizer
    startAudioLevelSimulation()

    print("[AppleTTSBackend] Starting speech synthesis...")
    synthesizer.speak(utterance)
  }

  /// Stop speaking immediately
  public func stop() {
    synthesizer.stopSpeaking(at: .immediate)
    stopAudioLevelSimulation()
    currentUtterance = nil
    currentText = ""
  }

  /// Pause speaking
  public func pause() {
    if synthesizer.isSpeaking {
      synthesizer.pauseSpeaking(at: .word)
      stopAudioLevelSimulation()
    }
  }

  /// Resume speaking after pause
  public func resume() {
    if synthesizer.isPaused {
      synthesizer.continueSpeaking()
      startAudioLevelSimulation()
    }
  }

  /// Check if currently speaking
  public var isSpeaking: Bool {
    synthesizer.isSpeaking
  }

  /// Check if paused
  public var isPaused: Bool {
    synthesizer.isPaused
  }

  // MARK: - Configuration Update

  /// Update configuration from TTSConfiguration
  public func updateConfiguration(_ config: TTSConfiguration) {
    if let voiceId = config.appleVoiceIdentifier {
      voice = AVSpeechSynthesisVoice(identifier: voiceId)
    }
    rate = config.appleRate
    pitch = config.applePitch
  }

  // MARK: - Audio Level Simulation

  private func startAudioLevelSimulation() {
    stopAudioLevelSimulation()

    // Create a timer that updates audio level at ~30fps
    audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self = self else { return }

        // Generate smooth, natural-looking audio levels
        let time = Date().timeIntervalSince1970
        let wave1 = sin(time * 8.0) * 0.3
        let wave2 = sin(time * 12.0) * 0.2
        let wave3 = sin(time * 5.0) * 0.15
        let baseLevel: Double = 0.4

        let level = Float(baseLevel + wave1 + wave2 + wave3)
        let clampedLevel = max(0.1, min(1.0, level))
        self.delegate?.ttsBackendDidUpdateAudioLevel(clampedLevel)
      }
    }
  }

  private func stopAudioLevelSimulation() {
    audioLevelTimer?.invalidate()
    audioLevelTimer = nil
  }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AppleTTSBackend: AVSpeechSynthesizerDelegate {

  nonisolated public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didStart utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      self.delegate?.ttsBackendDidStartSpeaking()
    }
  }

  nonisolated public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      self.stopAudioLevelSimulation()
      self.delegate?.ttsBackendDidUpdateAudioLevel(0)
      self.delegate?.ttsBackendDidUpdateProgress(1.0)
      self.delegate?.ttsBackendDidFinishSpeaking()
      self.currentUtterance = nil
    }
  }

  nonisolated public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      self.stopAudioLevelSimulation()
      self.delegate?.ttsBackendDidUpdateAudioLevel(0)
      self.delegate?.ttsBackendDidUpdateProgress(0)
      self.delegate?.ttsBackendDidCancel()
      self.currentUtterance = nil
    }
  }

  nonisolated public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    willSpeakRangeOfSpeechString characterRange: NSRange,
    utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      // Calculate progress based on character position
      let totalLength = self.currentText.count
      guard totalLength > 0 else { return }

      let progress = Float(characterRange.location + characterRange.length) / Float(totalLength)
      self.delegate?.ttsBackendDidUpdateProgress(min(1.0, progress))
    }
  }

  nonisolated public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didPause utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      self.stopAudioLevelSimulation()
      self.delegate?.ttsBackendDidPause()
    }
  }

  nonisolated public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didContinue utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in
      self.startAudioLevelSimulation()
      self.delegate?.ttsBackendDidResume()
    }
  }
}
