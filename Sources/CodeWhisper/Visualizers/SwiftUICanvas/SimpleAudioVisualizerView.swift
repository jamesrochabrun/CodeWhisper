//
//  SimpleAudioVisualizerView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/24/25.
//

import SwiftUI

/// A dynamic, organic audio visualizer with orbiting elements and fluid animations.
public struct SimpleAudioVisualizerView: View {

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
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                // Background ambient glow
                AmbientGlow(audioLevel: audioLevel, palette: currentPalette, time: time)

                // Outer ring of small particles
                ParticleRing(audioLevel: audioLevel, palette: currentPalette, time: time)

                // Orbiting blobs with trails (3 at different speeds)
                ForEach(0..<3, id: \.self) { index in
                    OrbitingBlobWithTrail(
                        audioLevel: audioLevel,
                        palette: currentPalette,
                        index: index,
                        time: time
                    )
                }

                // Central pulsing orb with glow and shine
                CentralOrb(audioLevel: audioLevel, palette: currentPalette, time: time)
            }
        }
        .frame(width: 200, height: 200)
    }
}

// MARK: - Central Orb with Glow and Shine

private struct CentralOrb: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval

    // Breathing animation with slight wobble
    private var breathe: CGFloat {
        let base = CGFloat(sin(time * 1.5) * 0.08 + 0.92)
        let wobble = CGFloat(sin(time * 3.7) * 0.02)
        return base + wobble
    }

    // Audio-reactive pulse
    private var audioPulse: CGFloat {
        1.0 + audioLevel * 0.7
    }

    // Base orb size
    private var orbSize: CGFloat {
        50 * breathe * audioPulse
    }

    // Glow expands with audio
    private var glowSize: CGFloat {
        orbSize * 2.8 * (1.0 + audioLevel * 1.0)
    }

    // Subtle rotation for the highlight
    private var highlightAngle: CGFloat {
        CGFloat(sin(time * 0.5) * 0.15)
    }

    var body: some View {
        ZStack {
            // Outer glow - expands dramatically with audio
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accent.opacity(0.4 * (1.0 + audioLevel * 0.8)),
                            palette.accent.opacity(0.2 * (1.0 + audioLevel * 0.5)),
                            palette.accent.opacity(0)
                        ],
                        center: .center,
                        startRadius: orbSize * 0.3,
                        endRadius: glowSize * 0.5
                    )
                )
                .frame(width: glowSize, height: glowSize)
                .blur(radius: 10 + audioLevel * 15)

            // Secondary glow ring
            Circle()
                .stroke(
                    palette.accent.opacity(0.3 + audioLevel * 0.3),
                    lineWidth: 2 + audioLevel * 3
                )
                .frame(width: orbSize * 1.6, height: orbSize * 1.6)
                .blur(radius: 4 + audioLevel * 4)

            // Main orb with gradient (offset for 3D effect)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accent,
                            palette.primary,
                            palette.secondary
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: orbSize * 0.6
                    )
                )
                .frame(width: orbSize, height: orbSize)

            // Inner shine/highlight (animated position)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.9 + audioLevel * 0.1),
                            .white.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 0.22
                    )
                )
                .frame(width: orbSize * 0.35, height: orbSize * 0.35)
                .offset(
                    x: -orbSize * 0.18 + highlightAngle * orbSize * 0.1,
                    y: -orbSize * 0.18 - highlightAngle * orbSize * 0.05
                )
        }
    }
}

// MARK: - Orbiting Blob with Trail Effect

private struct OrbitingBlobWithTrail: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let index: Int
    let time: TimeInterval

    // Each blob has different characteristics
    private var config: BlobConfig {
        BlobConfig.configs[index]
    }

    // Phase offset (120° apart base, but slightly varied)
    private var phaseOffset: Double {
        Double(index) * (.pi * 2 / 3) + config.phaseVariation
    }

    // Orbit radius with breathing effect
    private var orbitRadius: CGFloat {
        let base: CGFloat = 52 + CGFloat(index) * 5
        let audioExpand = audioLevel * 25
        let breathe = CGFloat(sin(time * config.breatheSpeed + phaseOffset) * 8)
        return base + audioExpand + breathe
    }

    // Blob size
    private var blobSize: CGFloat {
        config.baseSize + audioLevel * 12
    }

    // Current angle based on time (different speeds per blob)
    private var currentAngle: Double {
        time * config.orbitSpeed + phaseOffset
    }

    // Trail positions (slightly behind)
    private func trailAngle(_ trailIndex: Int) -> Double {
        currentAngle - Double(trailIndex + 1) * 0.15
    }

    var body: some View {
        ZStack {
            // Trail effect (3 fading copies behind)
            ForEach(0..<3, id: \.self) { trailIndex in
                let angle = trailAngle(trailIndex)
                let trailRadius = orbitRadius - CGFloat(trailIndex) * 2
                let opacity = 0.3 - Double(trailIndex) * 0.1
                let size = blobSize * (1.0 - CGFloat(trailIndex) * 0.15)

                Circle()
                    .fill(palette.accent.opacity(opacity * (0.5 + audioLevel * 0.5)))
                    .frame(width: size, height: size)
                    .blur(radius: 4 + CGFloat(trailIndex) * 2)
                    .offset(
                        x: cos(angle) * trailRadius,
                        y: sin(angle) * trailRadius
                    )
            }

            // Main blob with glow
            ZStack {
                // Blob glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.accent.opacity(0.5 + audioLevel * 0.4),
                                palette.accent.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: blobSize * 1.8
                        )
                    )
                    .frame(width: blobSize * 3.5, height: blobSize * 3.5)
                    .blur(radius: 5 + audioLevel * 4)

                // Main blob
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.accent.opacity(0.95),
                                palette.secondary.opacity(0.8)
                            ],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: blobSize * 0.6
                        )
                    )
                    .frame(width: blobSize, height: blobSize)
                    .blur(radius: 1 + audioLevel * 1.5)
            }
            .offset(
                x: cos(currentAngle) * orbitRadius,
                y: sin(currentAngle) * orbitRadius
            )
        }
        .opacity(0.75 + audioLevel * 0.25)
    }
}

// Configuration for each orbiting blob
private struct BlobConfig {
    let orbitSpeed: Double      // Radians per second
    let baseSize: CGFloat       // Base blob size
    let breatheSpeed: Double    // How fast the orbit breathes
    let phaseVariation: Double  // Slight offset from perfect 120°

    static let configs: [BlobConfig] = [
        BlobConfig(orbitSpeed: 0.9, baseSize: 16, breatheSpeed: 1.2, phaseVariation: 0),
        BlobConfig(orbitSpeed: 0.7, baseSize: 13, breatheSpeed: 1.5, phaseVariation: 0.2),
        BlobConfig(orbitSpeed: 1.1, baseSize: 11, breatheSpeed: 0.9, phaseVariation: -0.15)
    ]
}

// MARK: - Particle Ring

private struct ParticleRing: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval

    private let particleCount = 8

    var body: some View {
        ForEach(0..<particleCount, id: \.self) { index in
            ParticleView(
                audioLevel: audioLevel,
                palette: palette,
                time: time,
                index: index,
                totalCount: particleCount
            )
        }
    }
}

private struct ParticleView: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval
    let index: Int
    let totalCount: Int

    private var baseAngle: Double {
        Double(index) * (.pi * 2 / Double(totalCount))
    }

    // Particles orbit slowly in opposite direction
    private var currentAngle: Double {
        baseAngle - time * 0.3
    }

    // Radius with wave motion
    private var radius: CGFloat {
        let base: CGFloat = 75 + audioLevel * 15
        let wave = CGFloat(sin(time * 2.5 + Double(index) * 0.7) * 5 * (1 + audioLevel))
        return base + wave
    }

    // Particle size pulses
    private var particleSize: CGFloat {
        let base: CGFloat = 3 + audioLevel * 4
        let pulse = CGFloat(sin(time * 3 + Double(index) * 0.5) * 0.3 + 0.7)
        return base * pulse
    }

    // Opacity fades in and out
    private var particleOpacity: Double {
        let fade = (sin(time * 2 + Double(index) * 0.8) + 1) / 2
        return (0.3 + audioLevel * 0.4) * fade
    }

    var body: some View {
        Circle()
            .fill(palette.accent)
            .frame(width: particleSize, height: particleSize)
            .blur(radius: 1 + audioLevel * 1.5)
            .offset(
                x: cos(currentAngle) * radius,
                y: sin(currentAngle) * radius
            )
            .opacity(particleOpacity)
    }
}

// MARK: - Ambient Glow

private struct AmbientGlow: View {
    let audioLevel: CGFloat
    let palette: ColorPalette
    let time: TimeInterval

    // Animated glow that shifts slightly
    private var glowOffset: CGPoint {
        CGPoint(
            x: CGFloat(sin(time * 0.4) * 5),
            y: CGFloat(cos(time * 0.3) * 5)
        )
    }

    // Pulsing scale
    private var pulseScale: CGFloat {
        let base = CGFloat(sin(time * 0.8) * 0.04 + 1.0)
        let audio = 1.0 + audioLevel * 0.3
        return base * audio
    }

    var body: some View {
        ZStack {
            // Primary glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.primary.opacity(0.25 + audioLevel * 0.2),
                            palette.primary.opacity(0.08),
                            palette.primary.opacity(0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(pulseScale)
                .offset(x: glowOffset.x, y: glowOffset.y)
                .blur(radius: 20)

            // Secondary moving glow for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accent.opacity(0.1 + audioLevel * 0.1),
                            palette.accent.opacity(0)
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .offset(x: -glowOffset.x * 1.5, y: -glowOffset.y * 1.5)
                .blur(radius: 25)
        }
    }
}
