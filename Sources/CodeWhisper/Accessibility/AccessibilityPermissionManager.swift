//
//  AccessibilityPermissionManager.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import ApplicationServices
import Observation

/// Manages macOS Accessibility permission checking and requesting.
/// Required for detecting focused text fields and inserting text into other applications.
@Observable
@MainActor
public final class AccessibilityPermissionManager {

    // MARK: - Public State

    /// Whether Accessibility permission is currently granted
    public private(set) var isEnabled: Bool = false

    /// Whether we have prompted the user for permission
    public private(set) var hasPromptedUser: Bool = false

    // MARK: - Initialization

    public init() {
        // Check initial permission state without prompting
        self.isEnabled = checkPermissionInternal(prompt: false)
    }

    // MARK: - Public Methods

    /// Check if Accessibility permission is granted (does not prompt user)
    /// - Returns: True if permission is granted
    @discardableResult
    public func checkPermission() -> Bool {
        isEnabled = checkPermissionInternal(prompt: false)
        return isEnabled
    }

    /// Request Accessibility permission from the user
    /// - Parameter prompt: If true, shows the system permission dialog
    /// - Returns: True if permission is granted
    @discardableResult
    public func requestPermission(prompt: Bool = true) -> Bool {
        if prompt {
            hasPromptedUser = true
        }
        isEnabled = checkPermissionInternal(prompt: prompt)
        return isEnabled
    }

    /// Open System Settings to the Accessibility privacy pane
    /// Use this when the user needs to manually grant permission
    public func openSystemSettings() {
        // macOS 13+ uses the new System Settings app
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Refresh the permission state
    /// Call this when returning from System Settings or periodically
    public func refreshPermissionState() {
        isEnabled = checkPermissionInternal(prompt: false)
    }

    // MARK: - Private Methods

    private func checkPermissionInternal(prompt: Bool) -> Bool {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt
        ]
        return AXIsProcessTrustedWithOptions(options)
    }
}
#endif
