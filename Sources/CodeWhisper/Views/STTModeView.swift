//
//  STTModeView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import SwiftUI

/// STT mode view for speech-to-text recording.
/// Automatically starts recording on appear, stops and transcribes when stopped.
/// Calls onDismiss when transcription completes or is cancelled.
public struct STTModeView: View {

  // MARK: - Configuration

  let height: CGFloat
  let onTranscription: ((String) -> Void)?
  let onDismiss: (() -> Void)?

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
    transcribedText: Binding<String> = .constant(""),
    stopRecordingAction: Binding<(() -> Void)?> = .constant(nil),
    onTranscription: ((String) -> Void)? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.height = height
    self._transcribedText = transcribedText
    self._stopRecordingAction = stopRecordingAction
    self.onTranscription = onTranscription
    self.onDismiss = onDismiss
  }
  
  // MARK: - Body
  
  public var body: some View {
    VStack {
      HStack(alignment: .center) {
        visualizer
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
    .background { glassBackground }
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
      stopRecordingAction = nil
    }
  }
  
  private var visualizer: some View {
    STTVisualizerView(
      audioLevel: sttManager.audioLevel,
      state: sttManager.state
    )
    .frame(height: height - 12)
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
  
  @ViewBuilder
  private var glassBackground: some View {
#if os(visionOS)
    Color.clear.glassBackgroundEffect()
#else
    Capsule()
      .fill(.ultraThinMaterial)
#endif
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
