//
//  SwiftUIAudioVisualizerView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

struct SwiftUIAudioVisualizerView: View {
  let conversationManager: ConversationManager
  @State private var time: TimeInterval = 0

  // Idle State Colors (Medium Coral)
  private let idleCenterColor = Color(red: 0.800, green: 0.471, blue: 0.361)
  private let idleEdgeColor = Color(red: 0.850, green: 0.550, blue: 0.450)

  // User Speaking Colors (Bright Vibrant Coral) - Very saturated and bright
  private let userCenterColor = Color(red: 0.950, green: 0.550, blue: 0.400)
  private let userEdgeColor = Color(red: 1.000, green: 0.650, blue: 0.500)

  // AI Thinking Colors (Medium-Dark Coral) - Muted but not too dark
  private let thinkingCenterColor = Color(red: 0.600, green: 0.350, blue: 0.280)
  private let thinkingEdgeColor = Color(red: 0.700, green: 0.450, blue: 0.350)

  // AI Speaking Colors (Light Bright Coral) - Airy and luminous
  private let aiCenterColor = Color(red: 0.900, green: 0.600, blue: 0.500)
  private let aiEdgeColor = Color(red: 0.950, green: 0.700, blue: 0.600)
  
  var body: some View {
    TimelineView(.animation) { timeline in
      Canvas { context, size in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let baseRadius: CGFloat = 80
        
        // Update time
        let currentTime = timeline.date.timeIntervalSinceReferenceDate
        
        // Calculate active level and colors based on state
        let (activeLevel, centerColor, edgeColor) = getStateProperties()
        
        // Idle breathing pulse
        let idlePulse = conversationManager.conversationState == .idle ?
        sin(currentTime * 1.5) * 15 : 0
        
        // Main radius with audio reactivity
        let mainRadius = baseRadius +
        CGFloat(activeLevel) * 100 +
        CGFloat(conversationManager.midFrequency) * 50 +
        idlePulse
        
        // Draw outer glow (low frequency)
        let lowFreqGlow = mainRadius + 30.0 + CGFloat(conversationManager.lowFrequency) * 40.0
        drawGlowCircle(
          context: &context,
          center: center,
          radius: lowFreqGlow,
          color: centerColor,
          opacity: Double(conversationManager.lowFrequency) * 0.3
        )
        
        // Draw mid-frequency ring
        let midRing = mainRadius - 15
        drawRing(
          context: &context,
          center: center,
          radius: midRing,
          width: 8 + CGFloat(conversationManager.midFrequency) * 15,
          color: edgeColor,
          opacity: 0.4 + Double(conversationManager.midFrequency) * 0.6
        )
        
        // Draw main circle with gradient
        drawMainCircle(
          context: &context,
          center: center,
          radius: mainRadius,
          centerColor: centerColor,
          edgeColor: edgeColor
        )
        
        // Draw high-frequency sparkles
        if conversationManager.highFrequency > 0.1 {
          drawSparkles(
            context: &context,
            center: center,
            radius: mainRadius,
            count: Int(conversationManager.highFrequency * 20),
            time: currentTime
          )
        }
        
        // Draw directional flow particles
        if conversationManager.conversationState == .userSpeaking {
          drawFlowParticles(
            context: &context,
            center: center,
            radius: mainRadius,
            direction: -1, // Inward
            color: centerColor,
            time: currentTime
          )
        } else if conversationManager.conversationState == .aiSpeaking {
          drawFlowParticles(
            context: &context,
            center: center,
            radius: mainRadius,
            direction: 1, // Outward
            color: centerColor,
            time: currentTime
          )
        }
        
        // Draw rotating pattern when AI is thinking
        if conversationManager.conversationState == .aiThinking {
          drawThinkingPattern(
            context: &context,
            center: center,
            radius: mainRadius,
            color: centerColor,
            time: currentTime
          )
        }
        
        // Inner core glow
        drawGlowCircle(
          context: &context,
          center: center,
          radius: mainRadius * 0.3,
          color: centerColor,
          opacity: 0.8
        )
      }
    }
  }
  
  private func getStateProperties() -> (Float, Color, Color) {
    let activeLevel: Float
    let centerColor: Color
    let edgeColor: Color
    
    switch conversationManager.conversationState {
    case .idle:
      activeLevel = max(conversationManager.audioLevel, conversationManager.aiAudioLevel) * 0.3
      centerColor = idleCenterColor
      edgeColor = idleEdgeColor
      
    case .userSpeaking:
      activeLevel = conversationManager.audioLevel
      centerColor = userCenterColor
      edgeColor = userEdgeColor
      
    case .aiThinking:
      activeLevel = conversationManager.aiAudioLevel
      centerColor = thinkingCenterColor
      edgeColor = thinkingEdgeColor
      
    case .aiSpeaking:
      activeLevel = conversationManager.aiAudioLevel
      centerColor = aiCenterColor
      edgeColor = aiEdgeColor
    }
    
    return (activeLevel, centerColor, edgeColor)
  }
  
  private func drawMainCircle(
    context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    centerColor: Color,
    edgeColor: Color
  ) {
    let circlePath = Circle()
      .path(in: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
      ))
    
    let gradient = Gradient(colors: [centerColor, edgeColor])
    let radialGradient = GraphicsContext.Shading.radialGradient(
      gradient,
      center: center,
      startRadius: 0,
      endRadius: radius
    )
    
    context.fill(circlePath, with: radialGradient)
  }
  
  private func drawGlowCircle(
    context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    color: Color,
    opacity: Double
  ) {
    let circlePath = Circle()
      .path(in: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
      ))
    
    context.opacity = opacity
    context.fill(circlePath, with: .color(color))
    context.opacity = 1.0
  }
  
  private func drawRing(
    context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    width: CGFloat,
    color: Color,
    opacity: Double
  ) {
    let outerRadius = radius + width / 2
    let innerRadius = radius - width / 2
    
    let outerCircle = Circle()
      .path(in: CGRect(
        x: center.x - outerRadius,
        y: center.y - outerRadius,
        width: outerRadius * 2,
        height: outerRadius * 2
      ))
    
    let innerCircle = Circle()
      .path(in: CGRect(
        x: center.x - innerRadius,
        y: center.y - innerRadius,
        width: innerRadius * 2,
        height: innerRadius * 2
      ))
    
    context.opacity = opacity
    var path = Path()
    path.addPath(outerCircle)
    path.addPath(innerCircle)
    context.fill(path, with: .color(color), style: FillStyle(eoFill: true))
    context.opacity = 1.0
  }
  
  private func drawSparkles(
    context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    count: Int,
    time: TimeInterval
  ) {
    for i in 0..<count {
      let angle = Double(i) * (2 * .pi / Double(count)) + time * 0.5
      let distance = radius * 0.7 + CGFloat.random(in: 0...(radius * 0.3))
      let x = center.x + cos(angle) * distance
      let y = center.y + sin(angle) * distance
      let sparkleSize: CGFloat = 3
      
      let sparklePath = Circle()
        .path(in: CGRect(
          x: x - sparkleSize,
          y: y - sparkleSize,
          width: sparkleSize * 2,
          height: sparkleSize * 2
        ))
      
      context.opacity = 0.8
      context.fill(sparklePath, with: .color(.white))
    }
    context.opacity = 1.0
  }
  
  private func drawFlowParticles(
    context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    direction: CGFloat,
    color: Color,
    time: TimeInterval
  ) {
    let particleCount = 12
    for i in 0..<particleCount {
      let angle = Double(i) * (2 * .pi / Double(particleCount))
      let flowOffset = (time * 2).truncatingRemainder(dividingBy: 1.0)
      let distance = direction > 0 ?
      radius * 0.5 + CGFloat(flowOffset) * radius * 0.5 :
      radius * (1.0 - CGFloat(flowOffset))
      
      let x = center.x + cos(angle) * distance
      let y = center.y + sin(angle) * distance
      let particleSize: CGFloat = 4
      
      let particlePath = Circle()
        .path(in: CGRect(
          x: x - particleSize,
          y: y - particleSize,
          width: particleSize * 2,
          height: particleSize * 2
        ))
      
      context.opacity = 0.6
      context.fill(particlePath, with: .color(color))
    }
    context.opacity = 1.0
  }
  
  private func drawThinkingPattern(
    context: inout GraphicsContext,
    center: CGPoint,
    radius: CGFloat,
    color: Color,
    time: TimeInterval
  ) {
    let armCount = 6
    let rotation = time * 3
    
    for i in 0..<armCount {
      let angle = Double(i) * (2 * .pi / Double(armCount)) + rotation
      let startDistance = radius * 0.6
      let endDistance = radius * 0.9
      
      let startX = center.x + cos(angle) * startDistance
      let startY = center.y + sin(angle) * startDistance
      let endX = center.x + cos(angle) * endDistance
      let endY = center.y + sin(angle) * endDistance
      
      var path = Path()
      path.move(to: CGPoint(x: startX, y: startY))
      path.addLine(to: CGPoint(x: endX, y: endY))
      
      context.opacity = 0.4
      context.stroke(
        path,
        with: .color(color),
        lineWidth: 3
      )
    }
    context.opacity = 1.0
  }
}

#Preview {
  SwiftUIAudioVisualizerView(conversationManager: ConversationManager())
    .frame(width: 300, height: 300)
    .background(Color.black)
}
