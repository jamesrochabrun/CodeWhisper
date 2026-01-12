//
//  TextInserter.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import ApplicationServices
import Carbon.HIToolbox


/// Method used to insert text
public enum TextInsertionMethod: String, Codable, Sendable {
    case accessibilityAPI
    case clipboardPaste
}

/// Result of a text insertion attempt
public enum TextInsertionResult: Sendable {
    case success(method: TextInsertionMethod)
    case failure(error: TextInsertionError)
}

/// Errors that can occur during text insertion
public enum TextInsertionError: Error, LocalizedError, Sendable {
    case noFocusedElement
    case elementNotEditable
    case accessibilityAPIFailed(String)
    case clipboardFailed(String)
    case allMethodsFailed

    public var errorDescription: String? {
        switch self {
        case .noFocusedElement:
            return "No text field is currently focused"
        case .elementNotEditable:
            return "The focused element is not editable"
        case .accessibilityAPIFailed(let reason):
            return "Accessibility API failed: \(reason)"
        case .clipboardFailed(let reason):
            return "Clipboard paste failed: \(reason)"
        case .allMethodsFailed:
            return "All text insertion methods failed"
        }
    }
}

/// Inserts text into focused text fields using Accessibility APIs with clipboard fallback.
@MainActor
public final class TextInserter {

    // MARK: - Properties

    /// The preferred insertion method (will fall back if this fails)
    public var preferredMethod: TextInsertionMethod = .accessibilityAPI

    /// Whether to restore clipboard contents after paste fallback
    public var restoreClipboard: Bool = true

    /// Delay before restoring clipboard (seconds)
    public var clipboardRestoreDelay: TimeInterval = 0.5

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Insert text into the specified element, or use clipboard paste if no element
    /// - Parameters:
    ///   - text: The text to insert
    ///   - element: The AXUIElement to insert into (nil = use clipboard paste)
    /// - Returns: The result of the insertion attempt
    public func insertText(_ text: String, into element: AXUIElement?) async -> TextInsertionResult {
        // If we have an element and prefer accessibility API, try it first
        if let element = element, preferredMethod == .accessibilityAPI {
            let axResult = insertViaAccessibilityAPI(text, into: element)
            if case .success = axResult {
                return axResult
            }
            // Fall through to clipboard method
        }

        // Try clipboard paste as fallback or primary method
        return await insertViaClipboard(text)
    }

    /// Insert text at the current cursor position (auto-detects focused element)
    /// - Parameter text: The text to insert
    /// - Returns: The result of the insertion attempt
    public func insertTextAtCursor(_ text: String) async -> TextInsertionResult {
        let focusDetector = SystemFocusDetector()

        if preferredMethod == .accessibilityAPI,
           let focused = focusDetector.getFocusedTextElement() {
            let axResult = insertViaAccessibilityAPI(text, into: focused.axElement)
            if case .success = axResult {
                return axResult
            }
        }

        // Fall back to clipboard
        return await insertViaClipboard(text)
    }

    // MARK: - Private Methods

    /// Insert text using the Accessibility API directly
    private func insertViaAccessibilityAPI(_ text: String, into element: AXUIElement) -> TextInsertionResult {
        // First, check if the element is editable
        var settable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)

        guard settableResult == .success, settable.boolValue else {
            return .failure(error: .elementNotEditable)
        }

        // Try to get current value and selection to insert at cursor
        var currentValueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValueRef)
        let currentValue = currentValueRef as? String ?? ""

        // Get selected text range (if any)
        var selectedRangeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRef)

        let newValue: String
        if let rangeValue = selectedRangeRef,
           CFGetTypeID(rangeValue) == AXValueGetTypeID(),
           AXValueGetType(rangeValue as! AXValue) == .cfRange {
            // There's a selection - replace it
            var cfRange = CFRange(location: 0, length: 0)
            AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange)

            let nsRange = NSRange(location: cfRange.location, length: cfRange.length)
            if let range = Range(nsRange, in: currentValue) {
                newValue = currentValue.replacingCharacters(in: range, with: text)
            } else {
                // Invalid range, append to end
                newValue = currentValue + text
            }
        } else {
            // No selection info - try to append or replace all
            // For simplicity, we'll replace the entire value
            // A more sophisticated implementation would track cursor position
            newValue = currentValue + text
        }

        // Set the new value
        let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFString)

        if setResult == .success {
            return .success(method: .accessibilityAPI)
        } else {
            return .failure(error: .accessibilityAPIFailed("SetAttributeValue returned \(setResult.rawValue)"))
        }
    }

    /// Insert text using clipboard and simulated Cmd+V
    private func insertViaClipboard(_ text: String) async -> TextInsertionResult {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents if we want to restore
        let savedClipboard: String?
        if restoreClipboard {
            savedClipboard = pasteboard.string(forType: .string)
        } else {
            savedClipboard = nil
        }

        // Set clipboard to our text
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            return .failure(error: .clipboardFailed("Failed to set clipboard contents"))
        }

        // Small delay to ensure clipboard is ready
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Simulate Cmd+V keystroke
        let pasteSuccess = simulatePaste()

        guard pasteSuccess else {
            // Restore clipboard even on failure
            if let saved = savedClipboard {
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
            return .failure(error: .clipboardFailed("Failed to simulate paste keystroke"))
        }

        // Restore clipboard after delay
        if let saved = savedClipboard {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(clipboardRestoreDelay * 1_000_000_000))
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
        }

        return .success(method: .clipboardPaste)
    }

    /// Simulate Cmd+V keystroke using CGEvent
    private func simulatePaste() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key code for 'V' is 9
        let vKeyCode: CGKeyCode = 9

        // Create key down event with Command modifier
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            return false
        }
        keyDown.flags = .maskCommand

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return false
        }
        keyUp.flags = .maskCommand

        // Post the events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
#endif
