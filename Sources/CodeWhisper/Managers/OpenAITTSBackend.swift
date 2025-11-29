//
//  OpenAITTSBackend.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/29/25.
//

import Foundation
import AVFoundation
import SwiftOpenAI

/// OpenAI TTS backend using the OpenAI Audio Speech API
@MainActor
public final class OpenAITTSBackend: NSObject {

  // MARK: - Public Properties

  public weak var delegate: TTSBackendDelegate?

  // MARK: - Configuration

  /// OpenAI TTS model
  public var model: OpenAITTSModel = .tts1

  /// OpenAI TTS voice
  public var voice: OpenAITTSVoice = .nova

  /// Speech speed (0.25 - 4.0, default 1.0)
  public var speed: Double = 1.0

  // MARK: - Private Properties

  private var service: OpenAIService?
  private var audioPlayer: AVAudioPlayer?
  private var audioLevelTimer: Timer?
  private var progressTimer: Timer?
  private var startTime: Date?
  private var estimatedDuration: TimeInterval = 0
  private var isSpeakingFlag: Bool = false

  // MARK: - Initialization

  public override init() {
    super.init()
  }

  // MARK: - Service Configuration

  /// Configure with OpenAI service
  public func configure(service: OpenAIService) {
    self.service = service
  }

  // MARK: - Public Methods

  /// Speak the given text using OpenAI TTS
  public func speak(text: String) async {
    print("[OpenAITTSBackend] speak() called with \(text.count) characters")

    // Stop any current speech
    stop()

    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      print("[OpenAITTSBackend] Text is empty after trimming, skipping")
      return
    }

    guard let service = service else {
      print("[OpenAITTSBackend] No OpenAI service configured")
      return
    }

    isSpeakingFlag = true
    delegate?.ttsBackendDidStartSpeaking()
    startAudioLevelSimulation()

    do {
      // Create speech parameters
      let parameters = AudioSpeechParameters(
        model: model.audioSpeechModel,
        input: text,
        voice: voice.audioSpeechVoice,
        responseFormat: .mp3,
        speed: speed
      )

      print("[OpenAITTSBackend] Calling OpenAI TTS API...")

      // Call OpenAI API
      let speechObject = try await service.createSpeech(parameters: parameters)
      let audioData = speechObject.output

      print("[OpenAITTSBackend] Received \(audioData.count) bytes of audio data")

      // Play the audio
      playAudio(from: audioData, textLength: text.count)

    } catch {
      print("[OpenAITTSBackend] Error: \(error)")
      stopAudioLevelSimulation()
      isSpeakingFlag = false
      delegate?.ttsBackendDidUpdateAudioLevel(0)
      delegate?.ttsBackendDidFinishSpeaking()
    }
  }

  /// Stop speaking immediately
  public func stop() {
    audioPlayer?.stop()
    audioPlayer = nil
    stopAudioLevelSimulation()
    stopProgressTimer()
    isSpeakingFlag = false
  }

  /// Pause speaking
  public func pause() {
    if let player = audioPlayer, player.isPlaying {
      player.pause()
      stopAudioLevelSimulation()
      delegate?.ttsBackendDidPause()
    }
  }

  /// Resume speaking after pause
  public func resume() {
    if let player = audioPlayer, !player.isPlaying {
      player.play()
      startAudioLevelSimulation()
      delegate?.ttsBackendDidResume()
    }
  }

  /// Check if currently speaking
  public var isSpeaking: Bool {
    isSpeakingFlag && (audioPlayer?.isPlaying ?? false)
  }

  // MARK: - Configuration Update

  /// Update configuration from TTSConfiguration
  public func updateConfiguration(_ config: TTSConfiguration) {
    model = config.openAIModel
    voice = config.openAIVoice
    speed = config.openAISpeed
  }

  // MARK: - Private Methods

  private func playAudio(from data: Data, textLength: Int) {
    do {
      // Initialize the audio player with the data
      audioPlayer = try AVAudioPlayer(data: data)
      audioPlayer?.delegate = self
      audioPlayer?.prepareToPlay()

      // Estimate duration based on audio player or text length
      if let duration = audioPlayer?.duration, duration > 0 {
        estimatedDuration = duration
      } else {
        // Rough estimate: ~150 words per minute, ~5 chars per word
        let wordCount = Double(textLength) / 5.0
        estimatedDuration = (wordCount / 150.0) * 60.0 / speed
      }

      startTime = Date()
      startProgressTimer()

      print("[OpenAITTSBackend] Playing audio, duration: \(estimatedDuration)s")
      audioPlayer?.play()

    } catch {
      print("[OpenAITTSBackend] Error playing audio: \(error.localizedDescription)")
      stopAudioLevelSimulation()
      isSpeakingFlag = false
      delegate?.ttsBackendDidUpdateAudioLevel(0)
      delegate?.ttsBackendDidFinishSpeaking()
    }
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

  // MARK: - Progress Timer

  private func startProgressTimer() {
    stopProgressTimer()

    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self = self,
              let startTime = self.startTime,
              self.estimatedDuration > 0 else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(1.0, Float(elapsed / self.estimatedDuration))
        self.delegate?.ttsBackendDidUpdateProgress(progress)
      }
    }
  }

  private func stopProgressTimer() {
    progressTimer?.invalidate()
    progressTimer = nil
    startTime = nil
  }
}

// MARK: - AVAudioPlayerDelegate

extension OpenAITTSBackend: AVAudioPlayerDelegate {

  nonisolated public func audioPlayerDidFinishPlaying(
    _ player: AVAudioPlayer,
    successfully flag: Bool
  ) {
    Task { @MainActor in
      self.stopAudioLevelSimulation()
      self.stopProgressTimer()
      self.isSpeakingFlag = false
      self.delegate?.ttsBackendDidUpdateAudioLevel(0)
      self.delegate?.ttsBackendDidUpdateProgress(1.0)
      self.delegate?.ttsBackendDidFinishSpeaking()
      self.audioPlayer = nil
    }
  }

  nonisolated public func audioPlayerDecodeErrorDidOccur(
    _ player: AVAudioPlayer,
    error: Error?
  ) {
    Task { @MainActor in
      print("[OpenAITTSBackend] Audio decode error: \(error?.localizedDescription ?? "unknown")")
      self.stopAudioLevelSimulation()
      self.stopProgressTimer()
      self.isSpeakingFlag = false
      self.delegate?.ttsBackendDidUpdateAudioLevel(0)
      self.delegate?.ttsBackendDidFinishSpeaking()
      self.audioPlayer = nil
    }
  }
}
