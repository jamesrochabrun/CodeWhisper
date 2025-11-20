//
//  SwiftUIAudioVisualizerView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

public struct SwiftUIAudioVisualizerView: View {
  
  let conversationManager: ConversationManager
  
  // Modern color palettes for different states
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
      Canvas { context, size in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let currentTime = timeline.date.timeIntervalSinceReferenceDate
        let audioLevel = getAudioLevel()
        let maxRadius = min(size.width, size.height) / 2 * 0.85
        
        // Ambient background
        drawAmbientGlow(
          context: &context,
          center: center,
          time: currentTime,
          audioLevel: audioLevel,
          maxRadius: maxRadius
        )
        
        // Rotating arc segments (main visual element)
        drawRotatingArcs(
          context: &context,
          center: center,
          time: currentTime,
          audioLevel: audioLevel,
          maxRadius: maxRadius
        )
        
        // Central orb
        drawCentralOrb(
          context: &context,
          center: center,
          time: currentTime,
          audioLevel: audioLevel,
          maxRadius: maxRadius
        )
        
        // Subtle particle ring
        drawParticleRing(
          context: &context,
          center: center,
          time: currentTime,
          audioLevel: audioLevel,
          maxRadius: maxRadius
        )
      }
    }
  }
  
  private func getAudioLevel() -> CGFloat {
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
  
  
  
  private func drawAmbientGlow(
    context: inout GraphicsContext,
    center: CGPoint,
    time: TimeInterval,
    audioLevel: CGFloat,
    maxRadius: CGFloat
  ) {
    let pulse = sin(time * 1.2) * 0.1 + 0.9
    // Scale radius significantly with audio level
    let audioScale = 1.0 + audioLevel * 0.8
    let radius = maxRadius * 0.9 * pulse * audioScale
    
    let gradient = Gradient(colors: [
      currentPalette.primary.opacity(0.15 * (1.0 + audioLevel * 1.2)),
      currentPalette.primary.opacity(0)
    ])
    
    let radialGradient = GraphicsContext.Shading.radialGradient(
      gradient,
      center: center,
      startRadius: radius * 0.3,
      endRadius: radius
    )
    
    let circlePath = Circle()
      .path(in: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
      ))
    
    context.fill(circlePath, with: radialGradient)
  }
  
  
  
  private func drawRotatingArcs(
    context: inout GraphicsContext,
    center: CGPoint,
    time: TimeInterval,
    audioLevel: CGFloat,
    maxRadius: CGFloat
  ) {
    let arcCount = 3
    let baseRadius = maxRadius * 0.55
    
    for i in 0..<arcCount {
      let rotationSpeed = 0.8 + Double(i) * 0.3
      let rotation = time * rotationSpeed + Double(i) * (.pi * 2 / 3)
      
      // Enhanced dynamic radius based on audio - bounce effect
      let radiusOffset = sin(time * 2 + Double(i)) * maxRadius * 0.05 * audioLevel
      let audioBounce = maxRadius * 0.15 * audioLevel // Increased bounce range
      let arcRadius = baseRadius + radiusOffset + audioBounce
      
      // Arc parameters - arc length increases with audio
      let baseArcLength = .pi * 0.5
      let arcLength = baseArcLength * (1.0 + audioLevel * 0.3)
      let startAngle = rotation
      let endAngle = rotation + arcLength
      
      // Stroke width bounces with audio
      let strokeWidth = maxRadius * 0.04 * (1 + audioLevel * 0.8)
      
      // Create arc path
      var path = Path()
      path.addArc(
        center: center,
        radius: arcRadius,
        startAngle: Angle(radians: startAngle),
        endAngle: Angle(radians: endAngle),
        clockwise: false
      )
      
      // Gradient for arc with enhanced brightness
      let gradient = Gradient(colors: [
        currentPalette.secondary.opacity(0.8 + audioLevel * 0.2),
        currentPalette.accent.opacity(0.9 + audioLevel * 0.1)
      ])
      
      let angularGradient = GraphicsContext.Shading.linearGradient(
        gradient,
        startPoint: CGPoint(
          x: center.x + Foundation.cos(startAngle) * arcRadius,
          y: center.y + sin(startAngle) * arcRadius
        ),
        endPoint: CGPoint(
          x: center.x + Foundation.cos(endAngle) * arcRadius,
          y: center.y + sin(endAngle) * arcRadius
        )
      )
      
      // Draw arc with glow that intensifies with audio
      context.opacity = 0.15 * (1 + audioLevel * 0.5)
      context.stroke(
        path,
        with: angularGradient,
        lineWidth: strokeWidth * 2.5
      )
      
      context.opacity = 0.8 + audioLevel * 0.2
      context.stroke(
        path,
        with: angularGradient,
        style: StrokeStyle(
          lineWidth: strokeWidth,
          lineCap: .round
        )
      )
    }
    
    context.opacity = 1.0
  }
  
  
  
  private func drawCentralOrb(
    context: inout GraphicsContext,
    center: CGPoint,
    time: TimeInterval,
    audioLevel: CGFloat,
    maxRadius: CGFloat
  ) {
    // Smooth breathing animation combined with audio bounce
    let breathe = sin(time * 1.5) * 0.08 + 0.92
    let audioPulse = 1.0 + audioLevel * 0.6 // Increased audio response
    let orbRadius = maxRadius * 0.18 * breathe * audioPulse
    
    // Outer glow expands dramatically with audio
    let glowExpansion = 1.0 + audioLevel * 0.8
    let glowRadius = orbRadius * 2.2 * glowExpansion
    let glowGradient = Gradient(colors: [
      currentPalette.accent.opacity(0.3 * (1.0 + audioLevel * 0.7)),
      currentPalette.accent.opacity(0)
    ])
    
    let glowRadial = GraphicsContext.Shading.radialGradient(
      glowGradient,
      center: center,
      startRadius: orbRadius,
      endRadius: glowRadius
    )
    
    let glowPath = Circle()
      .path(in: CGRect(
        x: center.x - glowRadius,
        y: center.y - glowRadius,
        width: glowRadius * 2,
        height: glowRadius * 2
      ))
    
    context.fill(glowPath, with: glowRadial)
    
    // Main orb with gradient
    let orbGradient = Gradient(colors: [
      currentPalette.accent,
      currentPalette.primary
    ])
    
    let orbRadial = GraphicsContext.Shading.radialGradient(
      orbGradient,
      center: CGPoint(
        x: center.x - orbRadius * 0.2,
        y: center.y - orbRadius * 0.2
      ),
      startRadius: 0,
      endRadius: orbRadius
    )
    
    let orbPath = Circle()
      .path(in: CGRect(
        x: center.x - orbRadius,
        y: center.y - orbRadius,
        width: orbRadius * 2,
        height: orbRadius * 2
      ))
    
    context.fill(orbPath, with: orbRadial)
    
    // Inner highlight brightens with audio
    let highlightRadius = orbRadius * 0.35
    let highlightPath = Circle()
      .path(in: CGRect(
        x: center.x - highlightRadius - orbRadius * 0.2,
        y: center.y - highlightRadius - orbRadius * 0.2,
        width: highlightRadius * 2,
        height: highlightRadius * 2
      ))
    
    context.opacity = 0.7 + audioLevel * 0.3
    context.fill(highlightPath, with: .color(.white))
    context.opacity = 1.0
  }
  
  
  
  private func drawParticleRing(
    context: inout GraphicsContext,
    center: CGPoint,
    time: TimeInterval,
    audioLevel: CGFloat,
    maxRadius: CGFloat
  ) {
    let particleCount = 12
    let baseRingRadius = maxRadius * 0.7
    
    // Ring expands outward with audio
    let audioExpansion = audioLevel * maxRadius * 0.15
    let ringRadius = baseRingRadius + audioExpansion
    
    for i in 0..<particleCount {
      let baseAngle = Double(i) * (2 * .pi / Double(particleCount))
      let waveOffset = sin(time * 2 + Double(i) * 0.5) * 0.15 * audioLevel
      let angle = baseAngle + time * 0.4
      
      let radius = ringRadius + waveOffset * maxRadius * 0.1
      let x = center.x + cos(angle) * radius
      let y = center.y + sin(angle) * radius
      
      // Particle size varies dramatically with audio
      let particleSize = maxRadius * 0.02 * (1 + audioLevel * 1.2)
      let fadePhase = (time * 3 + Double(i) * 0.3).truncatingRemainder(dividingBy: 2 * .pi)
      let fade = (sin(fadePhase) + 1) / 2
      
      let particlePath = Circle()
        .path(in: CGRect(
          x: x - particleSize,
          y: y - particleSize,
          width: particleSize * 2,
          height: particleSize * 2
        ))
      
      // Brightness increases with audio
      context.opacity = (0.6 + audioLevel * 0.4) * fade
      context.fill(particlePath, with: .color(currentPalette.accent))
    }
    
    context.opacity = 1.0
  }
}

// Modern color palette structure
public struct ColorPaletteTeal {
  let primary: Color
  let secondary: Color
  let accent: Color
  
  static let idle = ColorPalette(
    primary: Color(red: 0.2, green: 0.8, blue: 0.7),
    secondary: Color(red: 0.15, green: 0.65, blue: 0.6),
    accent: Color(red: 0.3, green: 0.95, blue: 0.85)
  )
  
  static let userSpeaking = ColorPalette(
    primary: Color(red: 0.1, green: 0.7, blue: 0.65),      // Deeper teal
    secondary: Color(red: 0.08, green: 0.55, blue: 0.52),   // Richer secondary
    accent: Color(red: 0.15, green: 0.85, blue: 0.78)       // Vibrant deep accent
  )
  
  static let aiThinking = ColorPalette(
    primary: Color(red: 0.25, green: 0.85, blue: 0.75),     // Brighter teal
    secondary: Color(red: 0.2, green: 0.7, blue: 0.65),     // Mid-tone
    accent: Color(red: 0.35, green: 1.0, blue: 0.9)         // Bright cyan-teal
  )
  
  static let aiSpeaking = ColorPalette(
    primary: Color(red: 0.15, green: 0.75, blue: 0.72),     // Balanced teal
    secondary: Color(red: 0.12, green: 0.6, blue: 0.58),    // Slightly muted
    accent: Color(red: 0.25, green: 0.9, blue: 0.88)        // Clear bright accent
  )
}

// Modern color palette structure
public struct ColorPalette {
  let primary: Color
  let secondary: Color
  let accent: Color
  
  static let idle = ColorPalette(
    primary: Color(red: 0.8, green: 0.47, blue: 0.36),      // #CC785C - warm coral
    secondary: Color(red: 0.7, green: 0.37, blue: 0.26),    // Deeper coral
    accent: Color(red: 0.9, green: 0.57, blue: 0.46)        // Lighter coral
  )
  
  static let userSpeaking = ColorPalette(
    primary: Color(red: 0.82, green: 0.45, blue: 0.32),     // Slightly warmer coral
    secondary: Color(red: 0.72, green: 0.35, blue: 0.22),   // Richer depth
    accent: Color(red: 0.92, green: 0.55, blue: 0.42)       // Brighter coral
  )
  
  static let aiThinking = ColorPalette(
    primary: Color(red: 0.78, green: 0.49, blue: 0.38),     // Softer coral
    secondary: Color(red: 0.68, green: 0.39, blue: 0.28),   // Muted depth
    accent: Color(red: 0.88, green: 0.59, blue: 0.48)       // Gentle coral
  )
  
  static let aiSpeaking = ColorPalette(
    primary: Color(red: 0.84, green: 0.48, blue: 0.34),     // Vibrant coral
    secondary: Color(red: 0.74, green: 0.38, blue: 0.24),   // Bold depth
    accent: Color(red: 0.94, green: 0.58, blue: 0.44)       // Bright coral
  )
}
