//
//  FloatingSTTMenuBar.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit

/// Controller for the Floating STT menu bar item.
/// Provides quick access to show/hide the floating button and quit the mode.
@MainActor
public final class FloatingSTTMenuBarController {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private weak var floatingManager: FloatingSTTManager?
    private var showMenuItem: NSMenuItem?
    private var hideMenuItem: NSMenuItem?

    // MARK: - Initialization

    public init(floatingManager: FloatingSTTManager) {
        self.floatingManager = floatingManager
        setupStatusItem()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Floating STT")
        }

        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let isVisible = floatingManager?.isVisible ?? false

        // Show
        let showItem = NSMenuItem(
            title: "Show Floating Button",
            action: #selector(showFloatingButton),
            keyEquivalent: ""
        )
        showItem.target = self
        showItem.isEnabled = !isVisible
        showMenuItem = showItem
        menu.addItem(showItem)

        // Hide
        let hideItem = NSMenuItem(
            title: "Hide Floating Button",
            action: #selector(hideFloatingButton),
            keyEquivalent: ""
        )
        hideItem.target = self
        hideItem.isEnabled = isVisible
        hideMenuItem = hideItem
        menu.addItem(hideItem)

        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Floating STT",
            action: #selector(quitFloatingSTT),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func showFloatingButton() {
        floatingManager?.show()
    }

    @objc private func hideFloatingButton() {
        floatingManager?.hide()
    }

    @objc private func openSettings() {
        floatingManager?.showSettings()
    }

    @objc private func quitFloatingSTT() {
        floatingManager?.shutdown()
    }

    // MARK: - Public Methods

    /// Updates the menu item state to reflect current visibility
    public func updateMenuState() {
        let isVisible = floatingManager?.isVisible ?? false
        showMenuItem?.isEnabled = !isVisible
        hideMenuItem?.isEnabled = isVisible
    }

    /// Removes the status item from the menu bar
    public func remove() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}
#endif
