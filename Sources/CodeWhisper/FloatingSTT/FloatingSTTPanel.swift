//
//  FloatingSTTPanel.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import SwiftUI

/// A floating NSPanel that hosts the STT button and stays on top of all windows.
public final class FloatingSTTPanel: NSPanel {

    // MARK: - Properties

    /// Callback when the panel is dragged to a new position
    public var onPositionChanged: ((CGPoint) -> Void)?

    /// The hosting view for SwiftUI content
    private var hostingView: NSHostingView<AnyView>?

    // MARK: - Initialization

    public init(size: CGFloat) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
    }

    // MARK: - Configuration

    private func configurePanel() {
        // Window level - floating above other windows
        level = .floating

        // Collection behavior - appear on all spaces, work with full screen
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Transparency
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Stay visible when app is not active
        hidesOnDeactivate = false

        // Allow dragging by window background
        isMovableByWindowBackground = true

        // Don't show in window lists
        isExcludedFromWindowsMenu = true

        // Ignore mouse events on transparent areas
        ignoresMouseEvents = false

        // Become key window for interaction but don't activate the app
        becomesKeyOnlyIfNeeded = true
    }

    // MARK: - Content

    /// Set the SwiftUI content view
    public func setContentView<Content: View>(_ view: Content) {
        let hostingView = NSHostingView(rootView: AnyView(view))
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        // Make hosting view transparent
        hostingView.layer?.backgroundColor = .clear

        self.contentView = hostingView
        self.hostingView = hostingView
    }

    /// Update the panel size
    public func updateSize(_ size: CGFloat) {
        let currentOrigin = frame.origin
        setFrame(NSRect(x: currentOrigin.x, y: currentOrigin.y, width: size, height: size), display: true)
    }

    // MARK: - Position

    /// Set the panel position
    public func setPosition(_ point: CGPoint) {
        setFrameOrigin(NSPoint(x: point.x, y: point.y))
    }

    /// Get the current position
    public var position: CGPoint {
        return CGPoint(x: frame.origin.x, y: frame.origin.y)
    }

    // MARK: - Mouse Handling

    public override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)

        // Notify about position change after drag
        onPositionChanged?(position)
    }

    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)

        // Final position update after drag ends
        onPositionChanged?(position)
    }

    // MARK: - Key Window Behavior

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Window Controller

/// Controller for managing the floating panel lifecycle
@MainActor
public final class FloatingSTTWindowController {

    // MARK: - Properties

    private var panel: FloatingSTTPanel?
    private let buttonSize: CGFloat
    private var contentViewProvider: (() -> AnyView)?

    /// Whether the panel is currently visible
    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Current position of the panel
    public var position: CGPoint {
        get { panel?.position ?? .zero }
        set { panel?.setPosition(newValue) }
    }

    /// Callback when position changes
    public var onPositionChanged: ((CGPoint) -> Void)?

    // MARK: - Initialization

    public init(buttonSize: CGFloat = 56) {
        self.buttonSize = buttonSize
    }

    // MARK: - Content

    /// Set the SwiftUI content view
    public func setContent<Content: View>(@ViewBuilder _ content: @escaping () -> Content) {
        contentViewProvider = { AnyView(content()) }

        // Update existing panel if visible
        if let panel = panel {
            panel.setContentView(content())
        }
    }

    // MARK: - Lifecycle

    /// Show the floating panel
    public func show(at position: CGPoint? = nil) {
        if panel == nil {
            createPanel()
        }

        if let position = position {
            panel?.setPosition(position)
        }

        panel?.orderFront(nil)
    }

    /// Hide the floating panel
    public func hide() {
        panel?.orderOut(nil)
    }

    /// Toggle visibility
    public func toggle(at position: CGPoint? = nil) {
        if isVisible {
            hide()
        } else {
            show(at: position)
        }
    }

    /// Update the button size
    public func updateSize(_ size: CGFloat) {
        panel?.updateSize(size)
    }

    // MARK: - Private

    private func createPanel() {
        let newPanel = FloatingSTTPanel(size: buttonSize)

        // Set position change handler
        newPanel.onPositionChanged = { [weak self] position in
            self?.onPositionChanged?(position)
        }

        // Set content if available
        if let contentProvider = contentViewProvider {
            newPanel.setContentView(contentProvider())
        }

        self.panel = newPanel
    }
}
#endif
