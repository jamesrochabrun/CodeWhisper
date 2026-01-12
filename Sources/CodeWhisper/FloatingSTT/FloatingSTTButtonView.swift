//
//  FloatingSTTButtonView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import SwiftUI

/// Compact floating button view for STT recording with 3D tappable appearance
public struct FloatingSTTButtonView: View {
  
  // MARK: - Properties
  
  @Bindable var sttManager: STTManager
  let buttonWidth: CGFloat
  let buttonHeight: CGFloat
  let canInsertText: Bool
  let onTap: () -> Void
  let onLongPress: (() -> Void)?
  
  @State private var isPressed: Bool = false
  @Environment(\.colorScheme) private var colorScheme

  /// Whether button should appear pushed (recording or transcribing)
  private var isPushed: Bool {
    sttManager.state.isRecording || sttManager.state.isTranscribing
  }

  /// Whether currently transcribing (for pulse animation)
  private var isTranscribing: Bool {
    sttManager.state.isTranscribing
  }
  // MARK: - Initialization
  
  public init(
    sttManager: STTManager,
    buttonWidth: CGFloat = 88,
    buttonHeight: CGFloat = 28,
    canInsertText: Bool = true,
    onTap: @escaping () -> Void,
    onLongPress: (() -> Void)? = nil
  ) {
    self.sttManager = sttManager
    self.buttonWidth = buttonWidth
    self.buttonHeight = buttonHeight
    self.canInsertText = canInsertText
    self.onTap = onTap
    self.onLongPress = onLongPress
  }
  
  public init(
    sttManager: STTManager,
    buttonSize: CGSize,
    canInsertText: Bool = true,
    onTap: @escaping () -> Void,
    onLongPress: (() -> Void)? = nil
  ) {
    self.sttManager = sttManager
    self.buttonWidth = buttonSize.width
    self.buttonHeight = buttonSize.height
    self.canInsertText = canInsertText
    self.onTap = onTap
    self.onLongPress = onLongPress
  }
  
  // MARK: - Body
  
  public var body: some View {
    ZStack {
      // 3D Button background with depth
      button3DBackground
      
      // Waveform bars - always visible, different states
      waveformContent
        .frame(width: buttonWidth * 0.6, height: buttonHeight * 0.5)
    }
    .frame(width: buttonWidth, height: buttonHeight)
    .scaleEffect(isPressed ? 0.94 : 1.0)
    .offset(y: isPressed ? 2 : 0) // Push down effect when pressed
    .animation(.easeInOut(duration: 0.1), value: isPressed)
    .onTapGesture {
      onTap()
    }
    .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
      isPressed = pressing
    }, perform: {
      onLongPress?()
    })
  }
  
  // MARK: - 3D Button Background

  @ViewBuilder
  private var button3DBackground: some View {
    if isTranscribing {
      // Pulsing brightness animation for transcribing state
      TimelineView(.animation(minimumInterval: 1/30)) { timeline in
        let time = timeline.date.timeIntervalSinceReferenceDate
        let pulse = sin(time * 3.5)  // Faster pulse
        button3DBackgroundContent
          .brightness(pulse * 0.2)  // Strong range: -0.2 to +0.2
      }
    } else {
      button3DBackgroundContent
    }
  }

  private var button3DBackgroundContent: some View {
    ZStack {
      // Outer shadow (deep, diffuse) - the "pit" the button sits in
      Capsule()
        .fill(Color.black.opacity(colorScheme == .dark ? 0.6 : 0.25))
        .offset(y: (isPressed || isPushed) ? 2 : 5)
        .blur(radius: (isPressed || isPushed) ? 3 : 8)

      // Mid shadow (sharper, closer)
      Capsule()
        .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
        .offset(y: (isPressed || isPushed) ? 1 : 3)
        .blur(radius: (isPressed || isPushed) ? 1 : 3)

      // Button base layer (darker edge visible underneath)
      Capsule()
        .fill(
          LinearGradient(
            colors: buttonEdgeColors,
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .offset(y: (isPressed || isPushed) ? 0.5 : 1.5)

      // Main button body with gradient for 3D convex effect
      Capsule()
        .fill(
          LinearGradient(
            colors: buttonGradientColors,
            startPoint: .top,
            endPoint: .bottom
          )
        )
      // Specular highlight band (sharp glass-like reflection)
        .overlay(
          Capsule()
            .fill(
              LinearGradient(
                stops: [
                  .init(color: .clear, location: 0),
                  .init(color: .clear, location: 0.08),
                  .init(color: .white.opacity((isPressed || isPushed) ? 0.25 : 0.75), location: 0.15),
                  .init(color: .white.opacity((isPressed || isPushed) ? 0.12 : 0.45), location: 0.28),
                  .init(color: .clear, location: 0.45),
                  .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .padding(1)
        )
      // Inner highlight stroke (top edge bevel) - dimmed when pushed
        .overlay(
          Capsule()
            .strokeBorder(
              LinearGradient(
                colors: [
                  .white.opacity((isPressed || isPushed) ? 0.18 : (colorScheme == .dark ? 0.55 : 0.85)),
                  .white.opacity((isPressed || isPushed) ? 0.06 : 0.15),
                  .clear,
                  .clear
                ],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: 1.5
            )
        )
      // Inner shadow when pushed (concave depth)
        .overlay(
          (isPressed || isPushed) ?
            Capsule()
              .fill(
                LinearGradient(
                  colors: [.black.opacity(0.15), .clear, .clear],
                  startPoint: .top,
                  endPoint: .center
                )
              )
              .padding(2)
            : nil
        )
      // Inner shadow stroke (bottom edge depth)
        .overlay(
          Capsule()
            .strokeBorder(
              LinearGradient(
                colors: [
                  .clear,
                  .clear,
                  .black.opacity(0.15),
                  .black.opacity(colorScheme == .dark ? 0.4 : 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: 1.5
            )
        )
    }
    .frame(width: buttonWidth, height: buttonHeight)
  }
  
  /// Edge colors (visible as thin dark line under button)
  private var buttonEdgeColors: [Color] {
    if case .error = sttManager.state {
      // Error - Subtle red edge
      return [Color(red: 0.45, green: 0.20, blue: 0.20), Color(red: 0.35, green: 0.15, blue: 0.15)]
    } else {
      // Dark metallic edge for glossy black button
      return [Color(red: 0.03, green: 0.03, blue: 0.05), Color(red: 0.01, green: 0.01, blue: 0.02)]
    }
  }

  private var buttonGradientColors: [Color] {
    if case .error = sttManager.state {
      // Error state - Subtle muted red
      return colorScheme == .dark
      ? [Color(red: 0.55, green: 0.25, blue: 0.25), Color(red: 0.40, green: 0.18, blue: 0.18)]
      : [Color(red: 0.75, green: 0.35, blue: 0.35), Color(red: 0.60, green: 0.28, blue: 0.28)]
    } else if isPushed {
      // Pushed: inverted glossy black gradient (concave)
      return [
        Color(red: 0.04, green: 0.04, blue: 0.06),  // darker top (shadow)
        Color(red: 0.08, green: 0.08, blue: 0.10),  // mid
        Color(red: 0.15, green: 0.15, blue: 0.18)   // lighter bottom
      ]
    } else {
      // Idle: glossy black gradient (convex)
      return [
        Color(red: 0.28, green: 0.28, blue: 0.32),  // lighter charcoal top (catches light)
        Color(red: 0.12, green: 0.12, blue: 0.14),  // mid black
        Color(red: 0.06, green: 0.06, blue: 0.08)   // deep black bottom
      ]
    }
  }

  // MARK: - Waveform Content
  
  @ViewBuilder
  private var waveformContent: some View {
    switch sttManager.state {
    case .idle:
      // Uniform height bars for idle state
      FloatingWaveformBars(
        levels: Array(repeating: Float(0.4), count: 7),
        barColor: barColor,
        animate: false
      )
    case .recording:
      // Animated bars based on audio levels
      FloatingWaveformBars(
        levels: boostedRecordingLevels,
        barColor: barColor,
        animate: true
      )
    case .transcribing:
      // Wave pulse animation
      TimelineView(.animation(minimumInterval: 1/30)) { timeline in
        let time = timeline.date.timeIntervalSinceReferenceDate
        FloatingWaveformBars(
          levels: wavePulseLevels(time: time),
          barColor: barColor,
          animate: true
        )
      }
    case .error:
      // Static bars showing error state
      FloatingWaveformBars(
        levels: Array(repeating: Float(0.1), count: 5),
        barColor: barColor,
        animate: false
      )
    }
  }
  
  private var barColor: Color {
    if case .error = sttManager.state {
      // White bars on red background
      return .white.opacity(0.6)
    } else {
      // White bars on glossy black for contrast
      return .white.opacity(0.75)
    }
  }
  
  /// Boosted recording levels with base height and amplification
  private var boostedRecordingLevels: [Float] {
    let rawLevels = sttManager.waveformLevels
    let baseLevel: Float = 0.35  // Minimum bar height (same as idle)
    let amplification: Float = 3.0  // Boost sensitivity

    // Map 8 raw levels to 7 bars
    return (0..<7).map { index in
      let mappedIndex = Int(Float(index) / 7.0 * Float(rawLevels.count))
      let rawLevel = rawLevels[min(mappedIndex, rawLevels.count - 1)]
      // Amplify and add base level, clamp to 0-1
      return min(1.0, baseLevel + rawLevel * amplification)
    }
  }

  /// Wave pulse levels for transcribing animation (7 bars, faster)
  private func wavePulseLevels(time: Double) -> [Float] {
    (0..<7).map { index in
      let offset = Double(index) * 0.25  // tighter offset
      let wave = sin(time * 6.0 + offset)  // faster wave
      return Float(0.3 + 0.25 * wave)
    }
  }

}

// MARK: - Floating Waveform Bars

/// Compact waveform visualization for the floating buttonSiento.
struct FloatingWaveformBars: View {

  let levels: [Float]
  let barColor: Color
  let animate: Bool

  private let barCount = 7
  private let barWidth: CGFloat = 3
  private let spacing: CGFloat = 2

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: spacing) {
        ForEach(0..<barCount, id: \.self) { index in
          RoundedRectangle(cornerRadius: barWidth / 2)
            .fill(barColor)
            .frame(width: barWidth, height: barHeight(for: index, maxHeight: geometry.size.height))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .animation(animate ? .spring(response: 0.08, dampingFraction: 0.5) : nil, value: levels)
  }

  private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
    let minHeight: CGFloat = 6
    let level: Float

    if levels.count >= barCount {
      let mappedIndex = Int(Float(index) / Float(barCount) * Float(levels.count))
      level = levels[min(mappedIndex, levels.count - 1)]
    } else if !levels.isEmpty {
      level = levels[index % levels.count]
    } else {
      level = 0.3
    }

    return minHeight + (maxHeight - minHeight) * CGFloat(level)
  }
}

// MARK: - Previews

#Preview("Idle - Light") {
  let manager = STTManager()
  FloatingSTTButtonView(sttManager: manager, onTap: {})
    .padding(40)
    .background(Color.gray.opacity(0.3))
    .preferredColorScheme(.light)
}

#Preview("Idle - Dark") {
  let manager = STTManager()
  FloatingSTTButtonView(sttManager: manager, onTap: {})
    .padding(40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#if DEBUG
private struct PreviewHost: View {
  let state: STTRecordingState
  let colorScheme: ColorScheme

  var body: some View {
    let manager = STTManager()
    manager.setPreviewState(state)
    return FloatingSTTButtonView(sttManager: manager, onTap: {})
      .padding(40)
      .background(colorScheme == .dark ? Color.black : Color.gray.opacity(0.3))
      .preferredColorScheme(colorScheme)
  }
}

#Preview("Recording - Light") {
  PreviewHost(state: .recording, colorScheme: .light)
}

#Preview("Recording - Dark") {
  PreviewHost(state: .recording, colorScheme: .dark)
}

#Preview("Transcribing - Light") {
  PreviewHost(state: .transcribing, colorScheme: .light)
}

#Preview("Transcribing - Dark") {
  PreviewHost(state: .transcribing, colorScheme: .dark)
}

#Preview("Error - Light") {
  PreviewHost(state: .error("Test error"), colorScheme: .light)
}

#Preview("Error - Dark") {
  PreviewHost(state: .error("Test error"), colorScheme: .dark)
}
#endif
#endif
