//
//  FloatingSTTButtonView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import SwiftUI

/// Compact floating button view for STT recording
public struct FloatingSTTButtonView: View {

    // MARK: - Properties

    @Bindable var sttManager: STTManager
    let buttonSize: CGFloat
    let canInsertText: Bool
    let onTap: () -> Void
    let onLongPress: (() -> Void)?

    @State private var pulseScale: CGFloat = 1.0
    @State private var isPressed: Bool = false

    // MARK: - Initialization

    public init(
        sttManager: STTManager,
        buttonSize: CGFloat = 56,
        canInsertText: Bool = true,
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.sttManager = sttManager
        self.buttonSize = buttonSize
        self.canInsertText = canInsertText
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background circle with glass effect
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: buttonSize, height: buttonSize)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

            // Recording indicator ring
            if sttManager.state.isRecording {
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: buttonSize - 6, height: buttonSize - 6)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseScale = 1.15
                        }
                    }
                    .onDisappear {
                        pulseScale = 1.0
                    }
            }

            // Content based on state
            contentView
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            isPressed = pressing
        }, perform: {
            onLongPress?()
        })
        .frame(width: buttonSize, height: buttonSize)
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        switch sttManager.state {
        case .idle:
            idleView
        case .recording:
            recordingView
        case .transcribing:
            transcribingView
        case .error:
            errorView
        }
    }

    private var idleView: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: buttonSize * 0.4))
            .foregroundStyle(canInsertText ? .primary : .secondary)
    }

    private var recordingView: some View {
        MiniWaveformView(
            levels: sttManager.waveformLevels,
            barCount: 5,
            barWidth: 3,
            spacing: 2,
            color: .red
        )
        .frame(width: buttonSize * 0.5, height: buttonSize * 0.4)
    }

    private var transcribingView: some View {
        ProgressView()
            .scaleEffect(0.8)
            .progressViewStyle(.circular)
    }

    private var errorView: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: buttonSize * 0.35))
            .foregroundStyle(.orange)
    }
}

// MARK: - Mini Waveform View

/// Compact waveform visualization for the floating button
struct MiniWaveformView: View {

    let levels: [Float]
    let barCount: Int
    let barWidth: CGFloat
    let spacing: CGFloat
    let color: Color

    init(
        levels: [Float],
        barCount: Int = 5,
        barWidth: CGFloat = 3,
        spacing: CGFloat = 2,
        color: Color = .red
    ) {
        self.levels = levels
        self.barCount = barCount
        self.barWidth = barWidth
        self.spacing = spacing
        self.color = color
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(color)
                        .frame(width: barWidth, height: barHeight(for: index, maxHeight: geometry.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeOut(duration: 0.05), value: levels)
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let minHeight: CGFloat = 4
        let level: Float

        // Map from 8 levels to barCount
        if levels.count >= barCount {
            let mappedIndex = Int(Float(index) / Float(barCount) * Float(levels.count))
            level = levels[min(mappedIndex, levels.count - 1)]
        } else if !levels.isEmpty {
            level = levels[index % levels.count]
        } else {
            level = 0
        }

        return minHeight + (maxHeight - minHeight) * CGFloat(level)
    }
}

// MARK: - Previews

#Preview("Idle") {
    let manager = STTManager()
    return FloatingSTTButtonView(
        sttManager: manager,
        buttonSize: 56,
        canInsertText: true,
        onTap: {}
    )
    .padding(20)
    .background(Color.gray.opacity(0.3))
}

#Preview("Idle - No Target") {
    let manager = STTManager()
    return FloatingSTTButtonView(
        sttManager: manager,
        buttonSize: 56,
        canInsertText: false,
        onTap: {}
    )
    .padding(20)
    .background(Color.gray.opacity(0.3))
}
#endif
