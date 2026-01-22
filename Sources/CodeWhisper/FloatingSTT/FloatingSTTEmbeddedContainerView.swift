//
//  FloatingSTTEmbeddedContainerView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 1/11/26.
//

#if os(macOS)
import AppKit
import SwiftUI

/// Container view for embedded mode - right-click to show settings popover
struct FloatingSTTEmbeddedContainerView: View {

  // MARK: - Properties

  @Bindable var sttManager: STTManager
  @Bindable var floatingManager: FloatingSTTManager
  let buttonSize: CGSize
  let canInsertText: Bool
  let onTap: () -> Void
  let onLongPress: (() -> Void)?

  @State private var showSettingsPopover: Bool = false

  /// Whether the STT manager is in idle state
  private var isIdle: Bool {
    sttManager.state == .idle
  }

  // MARK: - Body

  var body: some View {
    RightClickableView(
      onRightClick: {
        if isIdle {
          showSettingsPopover = true
        }
      }
    ) {
      FloatingSTTButtonView(
        sttManager: sttManager,
        buttonSize: buttonSize,
        canInsertText: canInsertText,
        onTap: onTap,
        onLongPress: onLongPress
      )
    }
    .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
      FloatingSTTSettingsView(
        manager: floatingManager,
        isPopover: true,
        onDismiss: { showSettingsPopover = false }
      )
    }
  }
}

// MARK: - Right Click Support

/// A wrapper view that detects right-click (two-finger click) events
private struct RightClickableView<Content: View>: NSViewRepresentable {
  let onRightClick: () -> Void
  @ViewBuilder let content: () -> Content

  func makeNSView(context: Context) -> RightClickHostingView<Content> {
    let view = RightClickHostingView(rootView: content())
    view.onRightClick = onRightClick
    return view
  }

  func updateNSView(_ nsView: RightClickHostingView<Content>, context: Context) {
    nsView.rootView = content()
    nsView.onRightClick = onRightClick
  }
}

/// Custom NSHostingView that intercepts right mouse clicks
private class RightClickHostingView<Content: View>: NSHostingView<Content> {
  var onRightClick: (() -> Void)?

  override func rightMouseDown(with event: NSEvent) {
    onRightClick?()
  }
}

// MARK: - Previews

#Preview("Embedded Container") {
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
