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

    // MARK: - Initialization

    public init(
        sttManager: STTManager,
        buttonWidth: CGFloat = 72,
        buttonHeight: CGFloat = 44,
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

    private var button3DBackground: some View {
        ZStack {
            // Outer shadow (deep, diffuse) - the "pit" the button sits in
            Capsule()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.6 : 0.25))
                .offset(y: isPressed ? 2 : 5)
                .blur(radius: isPressed ? 3 : 8)

            // Mid shadow (sharper, closer)
            Capsule()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                .offset(y: isPressed ? 1 : 3)
                .blur(radius: isPressed ? 1 : 3)

            // Button base layer (darker edge visible underneath)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: buttonEdgeColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: isPressed ? 0.5 : 1.5)

            // Main button body with gradient for 3D convex effect
            Capsule()
                .fill(
                    LinearGradient(
                        colors: buttonGradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Glossy highlight overlay (top shine)
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.25 : 0.5),
                                    .white.opacity(colorScheme == .dark ? 0.1 : 0.2),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(2)
                        .mask(
                            Capsule()
                                .padding(2)
                        )
                )
                // Inner highlight stroke (top edge bevel)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.4 : 0.7),
                                    .white.opacity(0.1),
                                    .clear,
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
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
        if sttManager.state.isRecording {
            return [Color(red: 0.4, green: 0.05, blue: 0.05), Color(red: 0.3, green: 0.02, blue: 0.02)]
        } else if sttManager.state.isTranscribing {
            return [Color(red: 0.05, green: 0.1, blue: 0.4), Color(red: 0.02, green: 0.05, blue: 0.3)]
        } else if case .error = sttManager.state {
            return [Color(red: 0.4, green: 0.2, blue: 0.05), Color(red: 0.3, green: 0.15, blue: 0.02)]
        } else {
            return colorScheme == .dark
                ? [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.08, green: 0.08, blue: 0.1)]
                : [Color(red: 0.55, green: 0.55, blue: 0.58), Color(red: 0.45, green: 0.45, blue: 0.48)]
        }
    }

    private var buttonGradientColors: [Color] {
        if sttManager.state.isRecording {
            // Recording state - red tones
            return colorScheme == .dark
                ? [Color(red: 0.8, green: 0.2, blue: 0.2), Color(red: 0.5, green: 0.1, blue: 0.1)]
                : [Color(red: 0.95, green: 0.3, blue: 0.3), Color(red: 0.75, green: 0.15, blue: 0.15)]
        } else if sttManager.state.isTranscribing {
            // Transcribing state - blue tones
            return colorScheme == .dark
                ? [Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.1, green: 0.2, blue: 0.5)]
                : [Color(red: 0.3, green: 0.5, blue: 0.95), Color(red: 0.15, green: 0.3, blue: 0.75)]
        } else if case .error = sttManager.state {
            // Error state - orange tones
            return colorScheme == .dark
                ? [Color(red: 0.8, green: 0.5, blue: 0.2), Color(red: 0.5, green: 0.3, blue: 0.1)]
                : [Color(red: 0.95, green: 0.6, blue: 0.3), Color(red: 0.75, green: 0.4, blue: 0.15)]
        } else {
            // Idle state - neutral/gray tones
            return colorScheme == .dark
                ? [Color(red: 0.35, green: 0.35, blue: 0.38), Color(red: 0.2, green: 0.2, blue: 0.22)]
                : [Color(red: 0.92, green: 0.92, blue: 0.94), Color(red: 0.78, green: 0.78, blue: 0.8)]
        }
    }

    // MARK: - Waveform Content

    @ViewBuilder
    private var waveformContent: some View {
        switch sttManager.state {
        case .idle:
            // Static bars at base height
            FloatingWaveformBars(
                levels: Array(repeating: Float(0.15), count: 5),
                barColor: barColor,
                animate: false
            )
        case .recording:
            // Animated bars based on audio levels
            FloatingWaveformBars(
                levels: sttManager.waveformLevels,
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
        switch sttManager.state {
        case .idle:
            return colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.5)
        case .recording:
            return .white.opacity(0.9)
        case .transcribing:
            return .white.opacity(0.85)
        case .error:
            return .white.opacity(0.6)
        }
    }

    /// Wave pulse levels for transcribing animation (same as STTVisualizerView)
    private func wavePulseLevels(time: Double) -> [Float] {
        (0..<5).map { index in
            let offset = Double(index) * 0.4
            let wave = sin(time * 3.0 + offset)
            return Float(0.25 + 0.2 * wave)
        }
    }
}

// MARK: - Floating Waveform Bars

/// Compact waveform visualization for the floating button
struct FloatingWaveformBars: View {

    let levels: [Float]
    let barColor: Color
    let animate: Bool

    private let barCount = 5
    private let barWidth: CGFloat = 4
    private let spacing: CGFloat = 3

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
        .animation(animate ? .easeOut(duration: 0.08) : nil, value: levels)
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let minHeight: CGFloat = 4
        let level: Float

        if levels.count >= barCount {
            let mappedIndex = Int(Float(index) / Float(barCount) * Float(levels.count))
            level = levels[min(mappedIndex, levels.count - 1)]
        } else if !levels.isEmpty {
            level = levels[index % levels.count]
        } else {
            level = 0.15
        }

        return minHeight + (maxHeight - minHeight) * CGFloat(level)
    }
}

// MARK: - Previews

#Preview("Idle - Light") {
    let manager = STTManager()
    return FloatingSTTButtonView(
        sttManager: manager,
        buttonWidth: 72,
        buttonHeight: 44,
        canInsertText: true,
        onTap: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.2))
    .preferredColorScheme(.light)
}

#Preview("Idle - Dark") {
    let manager = STTManager()
    return FloatingSTTButtonView(
        sttManager: manager,
        buttonWidth: 72,
        buttonHeight: 44,
        canInsertText: true,
        onTap: {}
    )
    .padding(40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Large Size") {
    let manager = STTManager()
    return FloatingSTTButtonView(
        sttManager: manager,
        buttonWidth: 96,
        buttonHeight: 58,
        canInsertText: true,
        onTap: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}
#endif
