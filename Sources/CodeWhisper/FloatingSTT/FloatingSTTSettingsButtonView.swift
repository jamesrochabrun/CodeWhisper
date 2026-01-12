//
//  FloatingSTTSettingsButtonView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 1/11/26.
//

#if os(macOS)
import SwiftUI

/// Small 3D capsule settings button matching the main button style
struct FloatingSTTSettingsButtonView: View {

  // MARK: - Properties

  let onTap: () -> Void

  @State private var isPressed: Bool = false
  @Environment(\.colorScheme) private var colorScheme

  // Smaller dimensions for settings button
  private let buttonWidth: CGFloat = 28
  private let buttonHeight: CGFloat = 24

  // MARK: - Body

  var body: some View {
    ZStack {
      // 3D background matching main button style
      button3DBackground

      // Gear icon
      Image(systemName: "gearshape.fill")
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.white.opacity(0.75))
    }
    .frame(width: buttonWidth, height: buttonHeight)
    .scaleEffect(isPressed ? 0.94 : 1.0)
    .offset(y: isPressed ? 1 : 0)
    .animation(.easeInOut(duration: 0.1), value: isPressed)
    .onTapGesture {
      onTap()
    }
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false }
    )
  }

  // MARK: - 3D Button Background

  private var button3DBackground: some View {
    ZStack {
      // Outer shadow (deep, diffuse)
      Capsule()
        .fill(Color.black.opacity(colorScheme == .dark ? 0.6 : 0.25))
        .offset(y: isPressed ? 1 : 3)
        .blur(radius: isPressed ? 2 : 5)

      // Mid shadow (sharper, closer)
      Capsule()
        .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
        .offset(y: isPressed ? 0.5 : 2)
        .blur(radius: isPressed ? 0.5 : 2)

      // Button base layer (darker edge visible underneath)
      Capsule()
        .fill(
          LinearGradient(
            colors: buttonEdgeColors,
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .offset(y: isPressed ? 0.25 : 1)

      // Main button body with gradient for 3D convex effect
      Capsule()
        .fill(
          LinearGradient(
            colors: buttonGradientColors,
            startPoint: .top,
            endPoint: .bottom
          )
        )
        // Specular highlight band
        .overlay(
          Capsule()
            .fill(
              LinearGradient(
                stops: [
                  .init(color: .clear, location: 0),
                  .init(color: .clear, location: 0.08),
                  .init(color: .white.opacity(isPressed ? 0.25 : 0.75), location: 0.15),
                  .init(color: .white.opacity(isPressed ? 0.12 : 0.45), location: 0.28),
                  .init(color: .clear, location: 0.45),
                  .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .padding(1)
        )
        // Inner highlight stroke (top edge bevel)
        .overlay(
          Capsule()
            .strokeBorder(
              LinearGradient(
                colors: [
                  .white.opacity(isPressed ? 0.18 : (colorScheme == .dark ? 0.55 : 0.85)),
                  .white.opacity(isPressed ? 0.06 : 0.15),
                  .clear,
                  .clear
                ],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: 1.5
            )
        )
        // Inner shadow when pressed
        .overlay(
          isPressed ?
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

  // MARK: - Colors

  private var buttonEdgeColors: [Color] {
    [Color(red: 0.03, green: 0.03, blue: 0.05), Color(red: 0.01, green: 0.01, blue: 0.02)]
  }

  private var buttonGradientColors: [Color] {
    if isPressed {
      // Pushed: inverted gradient (concave)
      return [
        Color(red: 0.04, green: 0.04, blue: 0.06),
        Color(red: 0.08, green: 0.08, blue: 0.10),
        Color(red: 0.15, green: 0.15, blue: 0.18)
      ]
    } else {
      // Idle: glossy black gradient (convex)
      return [
        Color(red: 0.28, green: 0.28, blue: 0.32),
        Color(red: 0.12, green: 0.12, blue: 0.14),
        Color(red: 0.06, green: 0.06, blue: 0.08)
      ]
    }
  }
}

// MARK: - Previews

#Preview("Settings Button - Light") {
  FloatingSTTSettingsButtonView(onTap: {})
    .padding(40)
    .background(Color.gray.opacity(0.3))
    .preferredColorScheme(.light)
}

#Preview("Settings Button - Dark") {
  FloatingSTTSettingsButtonView(onTap: {})
    .padding(40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
#endif
