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
    Group {
      if state.isTranscribing {
        // Animated wave pulse during transcribing
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
          let time = timeline.date.timeIntervalSinceReferenceDate
          WaveformBarsView(
            waveformLevels: wavePulseLevels(time: time),
            barColor: barColor,
            isActive: true
          )
        }
      } else {
        // Normal waveform display for other states
        WaveformBarsView(
          waveformLevels: effectiveWaveformLevels,
          barColor: barColor,
          isActive: state.isRecording
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Wave pulse levels for transcribing animation
  private func wavePulseLevels(time: Double) -> [Float] {
    (0..<8).map { index in
      let offset = Double(index) * 0.3  // Stagger each bar
      let wave = sin(time * 3.0 + offset)  // ~0.5 sec per cycle
      return Float(0.2 + 0.15 * wave)  // Range: 0.05 to 0.35
    }
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
