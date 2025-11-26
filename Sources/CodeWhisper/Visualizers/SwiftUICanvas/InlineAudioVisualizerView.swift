//
//  InlineAudioVisualizerView.swift
//  CodeWhisper
//
//  Created by Claude on 11/26/25.
//

import SwiftUI

/// A horizontal audio visualizer designed for inline/compact voice mode views.
/// Displays flowing particles and wave effects across the full width.
public struct InlineAudioVisualizerView: View {

    let conversationManager: ConversationManager

    private var audioLevel: CGFloat {
        switch conversationManager.conversationState {
        case .idle:
            return CGFloat(max(conversationManager.audioLevel, conversationManager.aiAudioLevel)) * 0.3
        case .userSpeaking:
            return CGFloat(conversationManager.audioLevel)
        case .aiThinking:
            return 0.5
        case .aiSpeaking:
            return CGFloat(conversationManager.aiAudioLevel)
        }
    }

    private var currentPalette: ColorPalette {
        switch conversationManager.conversationState {
        case .idle:
            return .idle
        case .userSpeaking:
            return .userSpeaking
        case .aiThinking:
            return .aiThinking
        case .aiSpeaking:
            return .aiSpeaking
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    // Background glow layer
                    HorizontalGlow(
                        audioLevel: audioLevel,
                        palette: currentPalette,
                        time: time,
                        width: geometry.size.width
                    )

                    // Flowing wave
                    FlowingWave(
                        audioLevel: audioLevel,
                        palette: currentPalette,
                        time: time,
                        width: geometry.size.width,
                        height: geometry.size.height
                    )

                    // Floating orbs that move horizontally
                    FloatingOrbs(
                        audioLevel: audioLevel,
                        palette: currentPalette,
                        time: time,
                        width: geometry.size.width,
                        height: geometry.size.height
                    )

                    // Central accent glow
                    CentralAccentGlow(
                        audioLevel: audioLevel,
                        palette: currentPalette,
                        time: time
                    )
                }
            }
        }
    }
}

// MARK: - Horizontal Background Glow

private struct HorizontalGlow: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval
    let width: CGFloat

    private var pulseScale: CGFloat {
        let base = CGFloat(sin(time * 0.8) * 0.1 + 1.0)
        let audio = 1.0 + audioLevel * 0.2
        return base * audio
    }

    var body: some View {
        // Gradient glow that spans horizontally
        LinearGradient(
            colors: [
                palette.primary.opacity(0),
                palette.primary.opacity(0.15 + audioLevel * 0.15),
                palette.accent.opacity(0.2 + audioLevel * 0.2),
                palette.primary.opacity(0.15 + audioLevel * 0.15),
                palette.primary.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .scaleEffect(x: pulseScale, y: 1.0)
        .blur(radius: 8)
    }
}

// MARK: - Flowing Wave

private struct FlowingWave: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            drawWaves(context: context, size: size)
        }
    }

    private func drawWaves(context: GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        let baseAmplitude: CGFloat = 5 + audioLevel * 10
        let amplitude = baseAmplitude * (size.height / 42)

        for layer in 0..<3 {
            let path = createWavePath(
                layer: layer,
                size: size,
                midY: midY,
                amplitude: amplitude
            )
            let layerOpacity = 0.3 - Double(layer) * 0.08
            let strokeOpacity = layerOpacity + Double(audioLevel) * 0.2
            let lineWidth: CGFloat = 1.5 - CGFloat(layer) * 0.3

            context.stroke(
                path,
                with: .color(palette.accent.opacity(strokeOpacity)),
                lineWidth: lineWidth
            )
        }
    }

    private func createWavePath(layer: Int, size: CGSize, midY: CGFloat, amplitude: CGFloat) -> Path {
        let layerOffset = Double(layer) * 0.5
        let layerAmplitude = amplitude * (1.0 - CGFloat(layer) * 0.2)
        let points = max(1, Int(size.width / 3))

        var path = Path()

        for i in 0...points {
            let x = CGFloat(i) * (size.width / CGFloat(points))
            let normalizedX = Double(x / size.width)
            let y = calculateWaveY(
                normalizedX: normalizedX,
                midY: midY,
                layerAmplitude: layerAmplitude,
                layerOffset: layerOffset
            )

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func calculateWaveY(normalizedX: Double, midY: CGFloat, layerAmplitude: CGFloat, layerOffset: Double) -> CGFloat {
        let phase1 = (normalizedX * 4 * .pi) + time * 2.0 + layerOffset
        let phase2 = (normalizedX * 6 * .pi) + time * 1.5 + layerOffset
        let phase3 = (normalizedX * 2 * .pi) + time * 0.8 + layerOffset

        let wave1 = CGFloat(sin(phase1)) * layerAmplitude
        let wave2 = CGFloat(sin(phase2)) * layerAmplitude * 0.5
        let wave3 = CGFloat(sin(phase3)) * layerAmplitude * 0.3

        return midY + wave1 + wave2 + wave3
    }
}

// MARK: - Floating Orbs

private struct FloatingOrbs: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval
    let width: CGFloat
    let height: CGFloat

    private let orbCount = 5

    var body: some View {
        ForEach(0..<orbCount, id: \.self) { index in
            FloatingOrb(
                audioLevel: audioLevel,
                palette: palette,
                time: time,
                index: index,
                totalCount: orbCount,
                containerWidth: width,
                containerHeight: height
            )
        }
    }
}

private struct FloatingOrb: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval
    let index: Int
    let totalCount: Int
    let containerWidth: CGFloat
    let containerHeight: CGFloat

    // Each orb has different speed and phase
    private var speed: Double {
        0.15 + Double(index) * 0.05
    }

    private var phase: Double {
        Double(index) * 0.7
    }

    // Position cycles across the width
    private var xPosition: CGFloat {
        let cycle = (time * speed + phase).truncatingRemainder(dividingBy: 1.0)
        let smoothCycle = CGFloat(cycle)
        return smoothCycle * containerWidth
    }

    // Vertical position oscillates
    private var yOffset: CGFloat {
        let wave = sin(time * 1.5 + phase * 2) * (5 + audioLevel * 8)
        return wave
    }

    // Size pulses with audio
    private var orbSize: CGFloat {
        let base: CGFloat = 6 + CGFloat(index % 3) * 2
        let pulse = CGFloat(sin(time * 2 + phase) * 0.2 + 1.0)
        let audioBoost = 1.0 + audioLevel * 0.5
        return base * pulse * audioBoost
    }

    // Opacity varies
    private var orbOpacity: Double {
        let fade = (sin(time * 1.2 + phase) + 1) / 2
        return (0.4 + audioLevel * 0.4) * (0.5 + fade * 0.5)
    }

    var body: some View {
        ZStack {
            // Orb glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accent.opacity(orbOpacity * 0.6),
                            palette.accent.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 2
                    )
                )
                .frame(width: orbSize * 4, height: orbSize * 4)
                .blur(radius: 3)

            // Main orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accent.opacity(orbOpacity),
                            palette.secondary.opacity(orbOpacity * 0.7)
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: orbSize * 0.6
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .blur(radius: 0.5)
        }
        .position(
            x: xPosition,
            y: containerHeight / 2 + yOffset
        )
    }
}

// MARK: - Central Accent Glow

private struct CentralAccentGlow: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval

    private var pulse: CGFloat {
        CGFloat(sin(time * 1.5) * 0.15 + 1.0) * (1.0 + audioLevel * 0.3)
    }

    var body: some View {
        // Subtle central glow that pulses
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        palette.accent.opacity(0.2 + audioLevel * 0.2),
                        palette.accent.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 60
                )
            )
            .frame(width: 120 * pulse, height: 30 * pulse)
            .blur(radius: 10)
    }
}
