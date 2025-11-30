//
//  STTRecorder.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import Foundation
@preconcurrency import AVFoundation
import SwiftOpenAI

/// Simple audio recorder for speech-to-text using AVAudioEngine.
/// Provides a straightforward way to capture microphone audio as PCM buffers.
@RealtimeActor
public final class STTRecorder {
  
  private let audioEngine = AVAudioEngine()
  private var isRecording = false
  
  public init() {}
  
  /// Start recording and return an AsyncStream of PCM buffers
  /// - Returns: An AsyncStream that yields AVAudioPCMBuffer as audio is captured
  /// - Throws: If the audio engine fails to start
  public func startRecording() throws -> AsyncStream<AVAudioPCMBuffer> {
    guard !isRecording else {
      // Return empty stream if already recording
      return AsyncStream { $0.finish() }
    }
    
    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    
    // Create stream
    let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
    
    // Install tap on input node
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      continuation.yield(buffer)
    }
    
    // Prepare and start
    audioEngine.prepare()
    try audioEngine.start()
    isRecording = true
    
    // Handle termination
    continuation.onTermination = { [weak self] _ in
      Task { @RealtimeActor in
        self?.stopRecording()
      }
    }
    
    return stream
  }
  
  /// Stop recording and clean up resources
  public func stopRecording() {
    guard isRecording else { return }
    
    audioEngine.inputNode.removeTap(onBus: 0)
    audioEngine.stop()
    isRecording = false
  }
}
