//
//  AudioAnalyzer.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/10/25.
//

import AVFoundation
import Accelerate

/// Utility for analyzing audio buffers to extract amplitude and frequency data
struct AudioAnalyzer {
  
  // MARK: - Amplitude Analysis
  
  /// Calculate RMS (Root Mean Square) amplitude from PCM buffer
  /// - Parameter buffer: Audio PCM buffer
  /// - Returns: RMS amplitude value between 0.0 and 1.0
  static func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.int16ChannelData?[0],
          buffer.frameLength > 0 else {
      return 0.0
    }
    
    var sum: Float = 0.0
    let frameLength = Int(buffer.frameLength)
    
    for i in 0..<frameLength {
      let sample = Float(channelData[i]) / Float(Int16.max)
      sum += sample * sample
    }
    
    return sqrt(sum / Float(frameLength))
  }
  
  /// Calculate peak amplitude from PCM buffer
  /// - Parameter buffer: Audio PCM buffer
  /// - Returns: Peak amplitude value between 0.0 and 1.0
  static func calculatePeak(buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.int16ChannelData?[0],
          buffer.frameLength > 0 else {
      return 0.0
    }
    
    var peak: Int16 = 0
    let frameLength = Int(buffer.frameLength)
    
    for i in 0..<frameLength {
      peak = max(peak, abs(channelData[i]))
    }
    
    return Float(peak) / Float(Int16.max)
  }
  
  /// Calculate RMS amplitude from base64-encoded PCM16 data
  /// - Parameter base64String: Base64-encoded PCM16 audio data
  /// - Returns: RMS amplitude value between 0.0 and 1.0
  static func calculateRMSFromBase64(base64String: String) -> Float {
    guard let audioData = Data(base64Encoded: base64String) else {
      return 0.0
    }
    
    return calculateRMSFromPCM16Data(audioData)
  }
  
  /// Calculate RMS amplitude from raw PCM16 data
  /// - Parameter data: Raw PCM16 audio data
  /// - Returns: RMS amplitude value between 0.0 and 1.0
  static func calculateRMSFromPCM16Data(_ data: Data) -> Float {
    guard data.count > 0 else { return 0.0 }
    
    let sampleCount = data.count / MemoryLayout<Int16>.size
    var sum: Float = 0.0
    
    data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
      let samples = bytes.bindMemory(to: Int16.self)
      for i in 0..<sampleCount {
        let sample = Float(samples[i]) / Float(Int16.max)
        sum += sample * sample
      }
    }
    
    return sqrt(sum / Float(sampleCount))
  }
  
  // MARK: - Frequency Analysis
  
  /// Frequency band data extracted from FFT analysis
  struct FrequencyBands {
    let low: Float      // 0-250 Hz
    let mid: Float      // 250-2000 Hz
    let high: Float     // 2000+ Hz
  }
  
  /// Analyze frequency content of audio buffer using FFT
  /// - Parameter buffer: Audio PCM buffer
  /// - Returns: Energy levels for low, mid, and high frequency bands
  static func analyzeFrequencies(buffer: AVAudioPCMBuffer) -> FrequencyBands {
    guard let channelData = buffer.floatChannelData?[0],
          buffer.frameLength > 0 else {
      return FrequencyBands(low: 0, mid: 0, high: 0)
    }
    
    let frameLength = Int(buffer.frameLength)
    
    // Use power of 2 for FFT
    let fftSize = nextPowerOf2(frameLength)
    let log2n = vDSP_Length(log2(Float(fftSize)))
    
    // Setup FFT
    guard let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else {
      return FrequencyBands(low: 0, mid: 0, high: 0)
    }
    defer { vDSP_destroy_fftsetup(fftSetup) }
    
    // Prepare input buffer (zero-padded if necessary)
    var realInput = [Float](repeating: 0.0, count: fftSize)
    var imagInput = [Float](repeating: 0.0, count: fftSize)
    
    // Copy samples to real part
    for i in 0..<min(frameLength, fftSize) {
      realInput[i] = channelData[i]
    }
    
    // Create split complex buffer
    var splitComplex = DSPSplitComplex(
      realp: &realInput,
      imagp: &imagInput
    )
    
    // Perform FFT
    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
    
    // Calculate magnitudes
    var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
    
    // Convert to decibels and normalize
    var normalizedMagnitudes = [Float](repeating: 0.0, count: magnitudes.count)
    var maxMagnitude: Float = 1.0
    vDSP_maxv(magnitudes, 1, &maxMagnitude, vDSP_Length(magnitudes.count))
    
    if maxMagnitude > 0 {
      for i in 0..<magnitudes.count {
        normalizedMagnitudes[i] = magnitudes[i] / maxMagnitude
      }
    }
    
    // Extract frequency bands
    // Assuming 48kHz sample rate (common for modern devices)
    let sampleRate: Float = 48000.0
    let frequencyResolution = sampleRate / Float(fftSize)
    
    let lowBandEnd = Int(250.0 / frequencyResolution)
    let midBandEnd = Int(2000.0 / frequencyResolution)
    
    let lowEnergy = calculateBandEnergy(normalizedMagnitudes, start: 1, end: lowBandEnd)
    let midEnergy = calculateBandEnergy(normalizedMagnitudes, start: lowBandEnd, end: midBandEnd)
    let highEnergy = calculateBandEnergy(normalizedMagnitudes, start: midBandEnd, end: normalizedMagnitudes.count)
    
    return FrequencyBands(
      low: lowEnergy,
      mid: midEnergy,
      high: highEnergy
    )
  }
  
  // MARK: - Smoothing
  
  /// Apply exponential moving average for smooth transitions
  /// - Parameters:
  ///   - current: Current value
  ///   - target: Target value
  ///   - smoothing: Smoothing factor (0.0 = no smoothing, 1.0 = maximum smoothing)
  /// - Returns: Smoothed value
  static func smoothValue(_ current: Float, target: Float, smoothing: Float = 0.8) -> Float {
    return current * smoothing + target * (1.0 - smoothing)
  }
  
  // MARK: - Private Helpers
  
  /// Calculate energy in a frequency band
  private static func calculateBandEnergy(_ magnitudes: [Float], start: Int, end: Int) -> Float {
    let validStart = max(0, start)
    let validEnd = min(magnitudes.count, end)
    
    guard validStart < validEnd else { return 0.0 }
    
    var sum: Float = 0.0
    for i in validStart..<validEnd {
      sum += magnitudes[i]
    }
    
    let average = sum / Float(validEnd - validStart)
    return min(1.0, average) // Clamp to 0.0-1.0 range
  }
  
  /// Find next power of 2 greater than or equal to n
  private static func nextPowerOf2(_ n: Int) -> Int {
    var power = 1
    while power < n {
      power *= 2
    }
    return power
  }
}
