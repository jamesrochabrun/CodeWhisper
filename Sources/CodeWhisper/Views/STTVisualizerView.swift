//
//  STTVisualizerView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import SwiftUI

/// Waveform visualizer for STT mode showing audio level bars driven by real waveform data.
/// Uses WaveformBarsView internally for the actual bar rendering.
public struct STTVisualizerView: View {
  
  /// Waveform levels array (8 values, 0.0 - 1.0)
  let waveformLevels: [Float]
  
  /// Current STT recording state
  let state: STTRecordingState
  
  public init(waveformLevels: [Float], state: STTRecordingState) {
    self.waveformLevels = waveformLevels
    self.state = state
  }
  
  public var body: some View {
    WaveformBarsView(
      waveformLevels: effectiveWaveformLevels,
      barColor: barColor,
      isActive: state.isRecording
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  private var barColor: Color {
    switch state {
    case .idle:
      return .white.opacity(0.3)
    case .recording:
      return .red.opacity(0.8)
    case .transcribing:
      return .blue.opacity(0.6)
    case .error:
      return .orange.opacity(0.6)
    }
  }
  
  /// Returns waveform levels, with slight animation for transcribing state
  private var effectiveWaveformLevels: [Float] {
    if state.isTranscribing {
      // Uniform slight elevation for transcribing state
      return Array(repeating: 0.25, count: 8)
    }
    return waveformLevels
  }
}

// MARK: - Previews

#Preview("Idle") {
  STTVisualizerView(
    waveformLevels: Array(repeating: 0, count: 8),
    state: .idle
  )
  .frame(height: 30)
  .padding()
  .background(Color.black)
}

#Preview("Recording - Varied Waveform") {
  STTVisualizerView(
    waveformLevels: [0.2, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.3],
    state: .recording
  )
  .frame(height: 30)
  .padding()
  .background(Color.black)
}

#Preview("Transcribing") {
  STTVisualizerView(
    waveformLevels: Array(repeating: 0, count: 8),
    state: .transcribing
  )
  .frame(height: 30)
  .padding()
  .background(Color.black)
}
