//
//  SystemFocusDetector.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import ApplicationServices

/// Detects the currently focused UI element system-wide using Accessibility APIs.
/// Used to identify text fields in any application for text insertion.
@MainActor
public final class SystemFocusDetector {

    // MARK: - Types

    /// Represents a focused text element in any application
    public struct FocusedElement {
        /// The underlying AXUIElement
        public let axElement: AXUIElement

        /// The accessibility role (e.g., AXTextField, AXTextArea)
        public let role: String

        /// Whether the element appears to be editable
        public let isEditable: Bool

        /// The current text value, if available
        public let currentValue: String?

        /// The owning application's name
        public let applicationName: String?
    }

    /// Roles that represent text input fields
    private static let textInputRoles: Set<String> = [
        "AXTextField",
        "AXTextArea",
        "AXComboBox",
        "AXSearchField",
        "AXSecureTextField"
    ]

    /// Roles that may contain editable text (web content)
    private static let webEditableRoles: Set<String> = [
        "AXWebArea",
        "AXGroup"
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Get the currently focused text element across all applications
    /// - Returns: A FocusedElement if a text field is focused, nil otherwise
    public func getFocusedTextElement() -> FocusedElement? {
        // Get the system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Get the focused UI element
        var focusedElementRef: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard focusResult == .success,
              let focusedElement = focusedElementRef as! AXUIElement? else {
            return nil
        }

        // Get the role of the focused element
        guard let role = getAttribute(focusedElement, attribute: kAXRoleAttribute) as? String else {
            return nil
        }

        // Check if it's a text input type
        let isTextInput = Self.textInputRoles.contains(role)
        let isWebEditable = Self.webEditableRoles.contains(role) && checkIfEditable(focusedElement)

        guard isTextInput || isWebEditable else {
            return nil
        }

        // Get additional information
        let currentValue = getAttribute(focusedElement, attribute: kAXValueAttribute) as? String
        let applicationName = getApplicationName(for: focusedElement)
        let isEditable = checkIfEditable(focusedElement)

        return FocusedElement(
            axElement: focusedElement,
            role: role,
            isEditable: isEditable,
            currentValue: currentValue,
            applicationName: applicationName
        )
    }

    /// Check if a text field is currently focused anywhere in the system
    /// - Returns: True if a text field is focused
    public func isTextFieldFocused() -> Bool {
        return getFocusedTextElement() != nil
    }

    /// Get the currently focused application
    /// - Returns: The frontmost application, if available
    public func getFocusedApplication() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }

    // MARK: - Private Helpers

    private func getAttribute(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }

    private func checkIfEditable(_ element: AXUIElement) -> Bool {
        // Check if the element is enabled
        if let enabled = getAttribute(element, attribute: kAXEnabledAttribute) as? Bool, !enabled {
            return false
        }

        // Check for explicit editable attribute (used in web content)
        if let editable = getAttribute(element, attribute: "AXEditable") as? Bool {
            return editable
        }

        // Check if value is settable
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        if result == .success && settable.boolValue {
            return true
        }

        // For standard text fields, assume editable if enabled
        if let role = getAttribute(element, attribute: kAXRoleAttribute) as? String,
           Self.textInputRoles.contains(role) {
            return true
        }

        return false
    }

    private func getApplicationName(for element: AXUIElement) -> String? {
        // Get the process ID
        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(element, &pid)
        guard pidResult == .success else { return nil }

        // Find the running application
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.first { $0.processIdentifier == pid }?.localizedName
    }
}
#endif
