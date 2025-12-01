//
//  STTModeView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import SwiftUI

/// STT mode view for speech-to-text recording.
/// Automatically starts recording on appear, stops and transcribes when stopped.
/// Optionally supports TTS playback when a TTSSpeaker is provided.
/// Calls onDismiss when transcription completes or is cancelled (unless TTS is active).
public struct STTModeView: View {
  
  // MARK: - Configuration
  
  let height: CGFloat
  let onTranscription: ((String) -> Void)?
  let onDismiss: (() -> Void)?
  
  /// Optional TTS speaker for STT+TTS mode
  let ttsSpeaker: TTSSpeaker?
  
  // MARK: - Bindings
  
  @Binding var transcribedText: String
  @Binding var stopRecordingAction: (() -> Void)?
  
  // MARK: - Environment
  
  @Environment(OpenAIServiceManager.self) private var serviceManager
  @Environment(\.dismiss) private var dismiss
  
  // MARK: - State
  
  @State private var sttManager = STTManager()
  
  // MARK: - Initialization
  
  public init(
    height: CGFloat = 42,
    ttsSpeaker: TTSSpeaker? = nil,
    transcribedText: Binding<String> = .constant(""),
    stopRecordingAction: Binding<(() -> Void)?> = .constant(nil),
    onTranscription: ((String) -> Void)? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.height = height
    self.ttsSpeaker = ttsSpeaker
    self._transcribedText = transcribedText
    self._stopRecordingAction = stopRecordingAction
    self.onTranscription = onTranscription
    self.onDismiss = onDismiss
  }
  
  // MARK: - Body
  
  public var body: some View {
    VStack {
      HStack(alignment: .center) {
        // Show TTS controls when speaking, otherwise show STT visualizer
        if let speaker = ttsSpeaker, speaker.state.isSpeaking {
          ttsControls(speaker: speaker)
        } else {
          visualizer
        }
        if sttManager.errorMessage != nil {
          errorIndicator
        }
      }
      .fixedSize(horizontal: true, vertical: false)
      if let errorMessage = sttManager.errorMessage {
        Text(errorMessage)
          .fixedSize(horizontal: true, vertical: false)
          .font(.caption)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .task {
      await initializeSTTMode()
      await sttManager.toggleRecording()
      // Expose stop action to parent
      stopRecordingAction = {
        Task { @MainActor in
          await sttManager.toggleRecording()
        }
      }
    }
    .onDisappear {
      // Stop recording without transcribing if view disappears
      sttManager.stop()
      ttsSpeaker?.stop()
      stopRecordingAction = nil
    }
  }
  
  private var visualizer: some View {
    STTVisualizerView(
      waveformLevels: sttManager.waveformLevels,
      state: sttManager.state
    )
    .frame(height: height - 12)
  }
  
  // MARK: - TTS Controls
  
  @ViewBuilder
  private func ttsControls(speaker: TTSSpeaker) -> some View {
    HStack(spacing: 8) {
      // Stop button
      Button {
        speaker.stop()
      } label: {
        ZStack {
          Circle()
            .fill(Color.green.opacity(0.8))
            .frame(width: 28, height: 28)
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 10, height: 10)
        }
      }
      .buttonStyle(.plain)
      .help("Stop speaking")
      
      // TTS Visualizer
      WaveformBarsView(
        waveformLevels: deriveTTSWaveform(speaker.audioLevel),
        barColor: .teal,
        isActive: true
      )
      .frame(height: height - 16)
    }
  }
  
  private func deriveTTSWaveform(_ audioLevel: Float) -> [Float] {
    (0..<8).map { index in
      let variation = Float(sin(Double(index) * 0.6 + Double(audioLevel) * 8) * 0.3 + 0.7)
      return min(1.0, audioLevel * variation)
    }
  }
  
  private var errorIndicator: some View {
    Circle()
      .fill(Color.red)
      .frame(width: 8, height: 8)
      .overlay(
        Circle()
          .stroke(Color.red.opacity(0.5), lineWidth: 2)
          .scaleEffect(1.5)
      )
      .allowsHitTesting(false)
  }

  // MARK: - STT Initialization
  
  private func initializeSTTMode() async {
    guard let service = serviceManager.service else {
      return
    }
    
    sttManager.configure(service: service)
    
    // Set up transcription callback
    sttManager.onTranscription = { text in
      // Update binding
      transcribedText = text
      // Call callback
      onTranscription?(text)
      // Auto-dismiss after transcription completes
      onDismiss?()
    }
  }
}

// MARK: - Previews

#Preview("Idle") {
  VStack {
    Spacer()
    STTModeView(
      height: 42,
      onTranscription: { text in
        print("Transcribed: \(text)")
      }
    )
    .padding()
  }
  .background(Color.black)
  .environment(OpenAIServiceManager())
}
