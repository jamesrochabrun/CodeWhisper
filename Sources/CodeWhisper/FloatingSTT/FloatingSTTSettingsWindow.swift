//
//  FloatingSTTSettingsWindow.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import SwiftUI

/// Window controller for the Floating STT Settings window
@MainActor
public final class FloatingSTTSettingsWindowController {

    // MARK: - Properties

    private var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?

    // MARK: - Public Methods

    /// Shows the settings window
    /// - Parameter manager: The FloatingSTT manager to use for the settings view
    public func showSettings(manager: FloatingSTTManager) {
        if let existingWindow = window, existingWindow.isVisible {
            // Bring existing window to front
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create the SwiftUI view with manager
        let settingsView = FloatingSTTSettingsView(manager: manager)

        // Create hosting controller
        let hosting = NSHostingController(rootView: AnyView(settingsView))
        hostingController = hosting

        // Create window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "Floating STT Settings"
        newWindow.contentViewController = hosting
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Set minimum size
        newWindow.minSize = NSSize(width: 400, height: 350)

        self.window = newWindow

        // Show window
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the settings window if open
    public func close() {
        window?.close()
    }

    /// Whether the settings window is currently visible
    public var isVisible: Bool {
        window?.isVisible ?? false
    }
}
#endif
