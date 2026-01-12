//
//  FloatingSTTEmbeddedContainerView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 1/11/26.
//

#if os(macOS)
import SwiftUI

/// Container view for embedded mode - shows settings button on hover
struct FloatingSTTEmbeddedContainerView: View {

  // MARK: - Properties

  @Bindable var sttManager: STTManager
  @Bindable var floatingManager: FloatingSTTManager
  let buttonSize: CGSize
  let canInsertText: Bool
  let onTap: () -> Void
  let onLongPress: (() -> Void)?

  @State private var isHovering: Bool = false
  @State private var showSettingsPopover: Bool = false

  // Layout constants
  private let settingsButtonWidth: CGFloat = 28
  private let spacing: CGFloat = 6

  /// Whether the STT manager is in idle state
  private var isIdle: Bool {
    sttManager.state == .idle
  }

  // MARK: - Body

  var body: some View {
    HStack(spacing: spacing) {
      // Main STT button
      FloatingSTTButtonView(
        sttManager: sttManager,
        buttonSize: buttonSize,
        canInsertText: canInsertText,
        onTap: onTap,
        onLongPress: onLongPress
      )

      // Settings button - appears on hover only when idle
      if isIdle && (isHovering || showSettingsPopover) {
        FloatingSTTSettingsButtonView {
          showSettingsPopover.toggle()
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
        .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
          FloatingSTTSettingsView(manager: floatingManager, isPopover: true)
        }
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovering)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isIdle)
    .contentShape(Rectangle())
    .onHover { hovering in
      handleHover(hovering)
    }
    .onChange(of: showSettingsPopover) { _, isShowing in
      // When popover closes and not hovering, hide settings button after delay
      if !isShowing && !isHovering {
        scheduleHideSettingsButton()
      }
    }
  }

  // MARK: - Private Methods

  private func handleHover(_ hovering: Bool) {
    if hovering {
      isHovering = true
    } else {
      // Only hide if popover is not showing
      if !showSettingsPopover {
        scheduleHideSettingsButton()
      }
    }
  }

  private func scheduleHideSettingsButton() {
    // Small delay for smoother UX when moving between buttons
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      if !showSettingsPopover {
        isHovering = false
      }
    }
  }
}

// MARK: - Previews

#Preview("Embedded Container - Idle") {
  let sttManager = STTManager()
  let floatingManager = FloatingSTTManager()
  FloatingSTTEmbeddedContainerView(
    sttManager: sttManager,
    floatingManager: floatingManager,
    buttonSize: CGSize(width: 88, height: 28),
    canInsertText: true,
    onTap: {},
    onLongPress: nil
  )
  .padding(40)
  .background(Color.gray.opacity(0.3))
}
#endif
