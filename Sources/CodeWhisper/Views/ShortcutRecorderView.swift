//
//  ShortcutRecorderView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

import AppKit
import SwiftUI

/// A view that allows users to record a keyboard shortcut by pressing keys
public struct ShortcutRecorderView: View {

  @Binding var shortcut: KeyboardShortcutConfiguration
  @State private var isRecording = false
  @State private var eventMonitor: Any?
  @State private var errorMessage: String?

  public init(shortcut: Binding<KeyboardShortcutConfiguration>) {
    self._shortcut = shortcut
  }

  public var body: some View {
    VStack(alignment: .trailing, spacing: 6) {
      HStack(spacing: 12) {
        // Shortcut display / recording area
        shortcutDisplay
          .frame(minWidth: 120)

        // Record button
        Button(isRecording ? "Cancel" : "Record") {
          if isRecording {
            stopRecording()
          } else {
            startRecording()
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        // Reset button
        if shortcut != .default {
          Button("Reset") {
            shortcut = .default
          }
          .buttonStyle(.borderless)
          .controlSize(.small)
          .foregroundStyle(.secondary)
        }
      }

      // Error message display
      if let error = errorMessage {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .onDisappear {
      stopRecording()
    }
  }

  @ViewBuilder
  private var shortcutDisplay: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6)
        .fill(isRecording ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .strokeBorder(isRecording ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
        )

      if isRecording {
        Text("Press shortcut...")
          .font(.system(.body, design: .rounded))
          .foregroundStyle(.secondary)
      } else {
        Text(shortcut.displayString)
          .font(.system(.body, design: .rounded, weight: .medium))
          .foregroundStyle(.primary)
      }
    }
    .frame(height: 28)
  }

  private func startRecording() {
    isRecording = true
    errorMessage = nil

    // Add local event monitor for key events
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      handleKeyEvent(event)
      return nil  // Consume the event
    }
  }

  private func stopRecording() {
    isRecording = false
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }

  private func handleKeyEvent(_ event: NSEvent) {
    // Escape cancels recording
    if event.keyCode == 53 {  // Escape key
      stopRecording()
      return
    }

    // Try to create a shortcut from the event
    if let newShortcut = KeyboardShortcutConfiguration(event: event) {
      // Check for reserved shortcuts
      if newShortcut.isReservedShortcut {
        errorMessage = "This shortcut is reserved by the system"
        return
      }

      shortcut = newShortcut
      stopRecording()
    } else {
      // No valid modifier was pressed
      errorMessage = "Please include Command, Option, or Control"
    }
  }
}

#Preview {
  struct PreviewWrapper: View {
    @State private var shortcut = KeyboardShortcutConfiguration.default

    var body: some View {
      VStack(spacing: 20) {
        ShortcutRecorderView(shortcut: $shortcut)
        Text("Current: \(shortcut.displayString)")
      }
      .padding()
      .frame(width: 300)
    }
  }

  return PreviewWrapper()
}
