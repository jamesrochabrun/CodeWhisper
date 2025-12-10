//
//  FloatingSTTSettingsView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import AppKit
import SwiftUI

/// Settings view for Floating STT mode
/// Contains button configuration, keyboard shortcut, and API key settings
public struct FloatingSTTSettingsView: View {

    @Environment(SettingsManager.self) private var settings
    @State private var hasAccessibilityPermission: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FloatingButtonSection(hasAccessibilityPermission: $hasAccessibilityPermission)
                KeyboardShortcutSection()
                APIKeySection()
            }
            .padding(24)
        }
        .frame(minWidth: 400, idealWidth: 450, minHeight: 350, idealHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            hasAccessibilityPermission = FloatingSTT.hasAccessibilityPermission
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Floating Button Section

private struct FloatingButtonSection: View {
    @Environment(SettingsManager.self) private var settings
    @Binding var hasAccessibilityPermission: Bool

    var body: some View {
        @Bindable var settings = settings

        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Accessibility permission status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility Permission")
                            .font(.body)
                        Text(hasAccessibilityPermission
                            ? "Text insertion enabled"
                            : "Required for inserting text into other apps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if hasAccessibilityPermission {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 18))
                    } else {
                        Button("Grant Access") {
                            FloatingSTT.requestAccessibilityPermission()
                            refreshPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .padding(8)
        } label: {
            SectionHeader(title: "Accessibility", icon: "hand.point.up.braille")
        }
    }

    private func refreshPermission() {
        hasAccessibilityPermission = FloatingSTT.hasAccessibilityPermission
    }
}

// MARK: - Keyboard Shortcut Section

private struct KeyboardShortcutSection: View {
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Toggle Recording")
                            .font(.body)
                        Text("Press this shortcut to start/stop recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ShortcutRecorderView(shortcut: $settings.recordingShortcut)
                }
            }
            .padding(8)
        } label: {
            SectionHeader(title: "Keyboard Shortcut", icon: "command")
        }
    }
}

// MARK: - API Key Section

private struct APIKeySection: View {
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if settings.isUsingEnvironmentVariable {
                    // Environment variable state
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Using Environment Variable")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("OPENAI_API_KEY")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    // API Key input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SecureField("Enter your OpenAI API Key", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)

                            if settings.hasValidAPIKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 18))
                            }
                        }

                        if settings.hasValidAPIKey {
                            Label("Stored securely in Keychain", systemImage: "lock.shield")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(8)
        } label: {
            SectionHeader(title: "OpenAI API Key", icon: "key")
        }
    }
}

// MARK: - Preview

#Preview {
    FloatingSTTSettingsView()
        .environment(SettingsManager())
}
#endif
