//
//  STTManager.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import Foundation
import Observation
import SwiftOpenAI
@preconcurrency import AVFoundation

/// Manages speech-to-text recording and transcription using OpenAI's Whisper API.
/// Supports tap-to-toggle recording with audio level monitoring for visualization.
@Observable
@MainActor
public final class STTManager {
  
  // MARK: - Public State
  
  /// Current recording state
  public private(set) var state: STTRecordingState = .idle
  
  /// Current audio level (0.0 - 1.0) for visualization
  public private(set) var audioLevel: Float = 0.0
  
  /// Waveform levels for each segment (8 values, 0.0 - 1.0) for waveform visualization
  public private(set) var waveformLevels: [Float] = Array(repeating: 0.0, count: 8)
  
  /// Error message if transcription failed
  public private(set) var errorMessage: String?
  
  // MARK: - Output
  
  /// Callback invoked when transcription completes
  public var onTranscription: ((String) -> Void)?
  
  // MARK: - Private Properties
  
  private var service: OpenAIService?
  private var recorder: STTRecorder?
  private var recordingTask: Task<Void, Never>?
  private var audioBuffers: [AVAudioPCMBuffer] = []
  private var smoothedAudioLevel: Float = 0.0
  private var smoothedWaveformLevels: [Float] = Array(repeating: 0.0, count: 8)
  
  // Audio format for recording
  private var recordingFormat: AVAudioFormat?
  
  // MARK: - Initialization

  public init() {}

  // MARK: - Preview Support

  #if DEBUG
  /// Set state for preview purposes only
  public func setPreviewState(_ newState: STTRecordingState) {
    self.state = newState
  }
  #endif

  // MARK: - Configuration
  
  /// Configure the manager with an OpenAI service for transcription
  /// - Parameter service: The OpenAI service to use for Whisper transcription
  public func configure(service: OpenAIService) {
    self.service = service
  }
  
  // MARK: - Public Methods
  
  /// Toggle recording state (tap-to-toggle behavior)
  /// Call this when the user taps the record button
  public func toggleRecording() async {
    switch state {
    case .idle, .error:
      await startRecording()
    case .recording:
      await stopRecordingAndTranscribe()
    case .transcribing:
      // Ignore taps while transcribing
      break
    }
  }
  
  /// Stop recording and clean up resources without transcribing
  public func stop() {
    recordingTask?.cancel()
    recordingTask = nil
    audioBuffers.removeAll()
    
    // Capture the recorder reference before entering RealtimeActor context
    let recorderToStop = recorder
    recorder = nil
    
    Task { @RealtimeActor in
      recorderToStop?.stopRecording()
    }
    
    state = .idle
    audioLevel = 0.0
    smoothedAudioLevel = 0.0
    waveformLevels = Array(repeating: 0.0, count: 8)
    smoothedWaveformLevels = Array(repeating: 0.0, count: 8)
    errorMessage = nil
  }
  
  // MARK: - Private Methods
  
  private func startRecording() async {
    // Request microphone permission
    let permissionGranted = await requestMicrophonePermission()
    guard permissionGranted else {
      state = .error("Microphone permission denied")
      errorMessage = "Microphone permission is required for speech-to-text"
      return
    }

    // Prepare state
    self.audioBuffers.removeAll()
    self.errorMessage = nil
    self.state = .recording
    
    // Start streaming microphone data
    recordingTask = Task { @RealtimeActor in
      // Create recorder on RealtimeActor
      let newRecorder = STTRecorder()
      await MainActor.run { self.recorder = newRecorder }
      
      do {
        let stream = try newRecorder.startRecording()
        
        for await buffer in stream {
          guard !Task.isCancelled else { break }
          
          // Store buffer for later transcription
          await MainActor.run {
            self.audioBuffers.append(buffer)
            
            // Store format from first buffer
            if self.recordingFormat == nil {
              self.recordingFormat = buffer.format
            }
          }
          
          // Calculate audio level for visualization
          let rms = AudioAnalyzer.calculateRMS(buffer: buffer)
          
          // Extract waveform segments for visualization
          let segments = AudioAnalyzer.extractWaveformSegments(buffer: buffer, segmentCount: 8)
          
          await MainActor.run {
            // Reduce smoothing from 0.7 to 0.3 for snappier response
            self.smoothedAudioLevel = AudioAnalyzer.smoothValue(
              self.smoothedAudioLevel,
              target: rms,
              smoothing: 0.3
            )
            self.audioLevel = self.smoothedAudioLevel
            
            // Smooth waveform levels array
            self.smoothedWaveformLevels = AudioAnalyzer.smoothWaveform(
              self.smoothedWaveformLevels,
              target: segments,
              smoothing: 0.3
            )
            self.waveformLevels = self.smoothedWaveformLevels
          }
        }
      } catch {
        await MainActor.run {
          self.state = .error(error.localizedDescription)
          self.errorMessage = "Recording error: \(error.localizedDescription)"
        }
      }
    }
  }
  
  private func stopRecordingAndTranscribe() async {

    // Stop recording
    recordingTask?.cancel()
    recordingTask = nil

    // Capture the recorder reference before entering RealtimeActor context
    let recorderToStop = recorder
    recorder = nil

    Task { @RealtimeActor in
      recorderToStop?.stopRecording()
    }

    // Check if we have audio data
    guard !audioBuffers.isEmpty else {
      state = .idle
      audioLevel = 0.0
      return
    }

    // Update state
    state = .transcribing
    audioLevel = 0.0

    do {
      // Convert buffers to audio file data
      guard let audioData = createWavFileData() else {
        throw NSError(domain: "STTManager", code: 1, userInfo: [
          NSLocalizedDescriptionKey: "Failed to convert audio buffers to file"
        ])
      }
      // Clear buffers
      audioBuffers.removeAll()

      // Check service is configured
      guard let service = service else {
        throw NSError(domain: "STTManager", code: 2, userInfo: [
          NSLocalizedDescriptionKey: "OpenAI service not configured. Call configure(service:) first."
        ])
      }

      // Create transcription request
      // Use "json" format so response can be properly parsed
      let parameters = AudioTranscriptionParameters(
        fileName: "recording.wav",
        file: audioData,
        model: .custom(model: "gpt-4o-mini-transcribe"),
        responseFormat: "json"
      )

      // Call Whisper API
      let result = try await service.createTranscription(parameters: parameters)

      // Success - update state and call callback
      state = .idle
      errorMessage = nil

      let transcribedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

      if !transcribedText.isEmpty {
        onTranscription?(transcribedText)
      } else {
        print("[STTManager] WARNING: Transcribed text is empty, not calling callback")
      }

    } catch {
      state = .error(error.localizedDescription)
      errorMessage = "Transcription failed: \(error.localizedDescription)"
      audioBuffers.removeAll()
    }
  }
  
  /// Convert accumulated PCM buffers to WAV file data
  private func createWavFileData() -> Data? {
    guard !audioBuffers.isEmpty,
          let format = recordingFormat else {
      return nil
    }
    
    // Calculate total frame count
    let totalFrames = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
    guard totalFrames > 0 else { return nil }
    
    // Create output format (16-bit PCM for Whisper compatibility)
    guard let outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: format.sampleRate,
      channels: 1,
      interleaved: true
    ) else { return nil }
    
    // Create converter if needed
    var converter: AVAudioConverter?
    if format.commonFormat != .pcmFormatInt16 || format.channelCount != 1 {
      converter = AVAudioConverter(from: format, to: outputFormat)
    }
    
    // Collect all samples
    var allSamples: [Int16] = []
    allSamples.reserveCapacity(totalFrames)
    
    for buffer in audioBuffers {
      if let converter = converter {
        // Convert buffer to output format
        guard let convertedBuffer = AVAudioPCMBuffer(
          pcmFormat: outputFormat,
          frameCapacity: buffer.frameLength
        ) else { continue }
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
          outStatus.pointee = .haveData
          return buffer
        }
        
        if status == .haveData || status == .endOfStream,
           let int16Data = convertedBuffer.int16ChannelData {
          let frameCount = Int(convertedBuffer.frameLength)
          for i in 0..<frameCount {
            allSamples.append(int16Data[0][i])
          }
        }
      } else if let int16Data = buffer.int16ChannelData {
        // Already in correct format
        let frameCount = Int(buffer.frameLength)
        for i in 0..<frameCount {
          allSamples.append(int16Data[0][i])
        }
      } else if let floatData = buffer.floatChannelData {
        // Convert float to int16
        let frameCount = Int(buffer.frameLength)
        for i in 0..<frameCount {
          let sample = floatData[0][i]
          let clampedSample = max(-1.0, min(1.0, sample))
          allSamples.append(Int16(clampedSample * Float(Int16.max)))
        }
      }
    }
    
    guard !allSamples.isEmpty else { return nil }
    
    // Create WAV file data
    return createWavData(samples: allSamples, sampleRate: UInt32(outputFormat.sampleRate))
  }
  
  /// Create WAV file data from Int16 samples
  private func createWavData(samples: [Int16], sampleRate: UInt32) -> Data {
    var data = Data()
    
    let numChannels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
    let blockAlign = numChannels * (bitsPerSample / 8)
    let dataSize = UInt32(samples.count * 2)
    let fileSize = 36 + dataSize
    
    // RIFF header
    data.append(contentsOf: "RIFF".utf8)
    data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
    data.append(contentsOf: "WAVE".utf8)
    
    // fmt subchunk
    data.append(contentsOf: "fmt ".utf8)
    data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // Subchunk1Size
    data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // AudioFormat (PCM)
    data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
    
    // data subchunk
    data.append(contentsOf: "data".utf8)
    data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
    
    // Audio samples
    for sample in samples {
      data.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
    }
    
    return data
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
