//
//  WaveformBarsView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import SwiftUI

/// Reusable waveform visualizer component that displays audio levels as animated bars.
/// Each bar can represent a different segment of the audio waveform for true waveform visualization.
public struct WaveformBarsView: View {
  
  /// Waveform levels array (one value per bar, 0.0 - 1.0)
  let waveformLevels: [Float]
  
  /// Color for all bars
  let barColor: Color
  
  /// Whether to animate based on waveform levels (false shows base height)
  let isActive: Bool
  
  /// Number of bars to display
  let barCount: Int
  
  public init(
    waveformLevels: [Float],
    barColor: Color,
    isActive: Bool = true,
    barCount: Int = 8
  ) {
    self.waveformLevels = waveformLevels
    self.barColor = barColor
    self.isActive = isActive
    self.barCount = barCount
  }
  
  public var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<barCount, id: \.self) { index in
        RoundedRectangle(cornerRadius: 2)
          .fill(barColor)
          .frame(width: 3)
          .frame(height: barHeight(for: index))
          .animation(.easeOut(duration: 0.05), value: waveformLevels)
      }
    }
  }
  
  private func barHeight(for index: Int) -> CGFloat {
    let baseHeight: CGFloat = 6
    let maxAdditional: CGFloat = 22
    
    if isActive {
      let level = index < waveformLevels.count ? waveformLevels[index] : 0.0
      return baseHeight + maxAdditional * CGFloat(level)
    } else {
      return baseHeight
    }
  }
}

// MARK: - Previews

#Preview("Idle") {
  WaveformBarsView(
    waveformLevels: Array(repeating: 0, count: 8),
    barColor: .white.opacity(0.3),
    isActive: false
  )
  .frame(height: 30)
  .padding()
  .background(Color.black)
}

#Preview("Recording - Varied") {
  WaveformBarsView(
    waveformLevels: [0.2, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.3],
    barColor: .red.opacity(0.8),
    isActive: true
  )
  .frame(height: 30)
  .padding()
  .background(Color.black)
}

#Preview("TTS Speaking") {
  WaveformBarsView(
    waveformLevels: [0.4, 0.7, 0.5, 0.8, 0.6, 0.9, 0.5, 0.4],
    barColor: .green.opacity(0.8),
    isActive: true
  )
  .frame(height: 30)
  .padding()
  .background(Color.black)
}
