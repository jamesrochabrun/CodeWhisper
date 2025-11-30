//
//  TTSVisualizerView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import SwiftUI

/// Simple visualizer for TTS mode showing speaking waves
public struct TTSVisualizerView: View {
  
  let audioLevel: Float
  let state: TTSSpeakingState
  
  private let waveCount = 3
  
  public init(audioLevel: Float, state: TTSSpeakingState) {
    self.audioLevel = audioLevel
    self.state = state
  }
  
  public var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<waveCount, id: \.self) { index in
        WaveBar(
          audioLevel: audioLevel,
          delay: Double(index) * 0.1,
          isSpeaking: state.isSpeaking
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - WaveBar

struct WaveBar: View {
  
  let audioLevel: Float
  let delay: Double
  let isSpeaking: Bool
  
  @State private var animationPhase: Double = 0
  
  var body: some View {
    RoundedRectangle(cornerRadius: 3)
      .fill(isSpeaking ? Color.green.opacity(0.7) : Color.white.opacity(0.3))
      .frame(width: 6)
      .frame(height: barHeight)
      .animation(.easeInOut(duration: 0.15), value: audioLevel)
      .onAppear {
        if isSpeaking {
          withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
            animationPhase = 1
          }
        }
      }
      .onChange(of: isSpeaking) { _, newValue in
        if newValue {
          withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
            animationPhase = 1
          }
        } else {
          animationPhase = 0
        }
      }
  }
  
  private var barHeight: CGFloat {
    let baseHeight: CGFloat = 10
    let maxAdditional: CGFloat = 18
    
    if isSpeaking {
      return baseHeight + maxAdditional * CGFloat(audioLevel)
    } else {
      return baseHeight
    }
  }
}

// MARK: - Previews

#Preview("Idle") {
  TTSVisualizerView(audioLevel: 0, state: .idle)
    .frame(height: 30)
    .padding()
    .background(Color.black)
}

#Preview("Speaking") {
  TTSVisualizerView(audioLevel: 0.7, state: .speaking)
    .frame(height: 30)
    .padding()
    .background(Color.black)
}

#Preview("Paused") {
  TTSVisualizerView(audioLevel: 0, state: .paused)
    .frame(height: 30)
    .padding()
    .background(Color.black)
}
