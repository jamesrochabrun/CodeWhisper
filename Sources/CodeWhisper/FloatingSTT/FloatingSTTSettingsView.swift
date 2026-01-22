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
/// Contains accessibility status and prompt enhancement settings
public struct FloatingSTTSettingsView: View {

    @Bindable var manager: FloatingSTTManager
    @State private var hasAccessibilityPermission: Bool = false

    /// Whether shown in a popover (affects sizing/padding)
    let isPopover: Bool

    /// Callback to dismiss the popover (only used when isPopover is true)
    let onDismiss: (() -> Void)?

    public init(manager: FloatingSTTManager, isPopover: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.manager = manager
        self.isPopover = isPopover
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Close button for popover mode
                if isPopover, let onDismiss {
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                    }
                }

                FloatingButtonSection(hasAccessibilityPermission: $hasAccessibilityPermission)
                PromptEnhancementSection(manager: manager)
            }
            .padding(isPopover ? 16 : 24)
        }
        .frame(
            minWidth: isPopover ? 350 : 400,
            idealWidth: isPopover ? 380 : 450,
            minHeight: isPopover ? 300 : 350,
            idealHeight: isPopover ? 350 : 400
        )
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
    @Binding var hasAccessibilityPermission: Bool

    var body: some View {
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

// MARK: - Prompt Enhancement Section

private struct PromptEnhancementSection: View {
    @Bindable var manager: FloatingSTTManager
    @State private var customPrompt: String = ""

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Toggle for enhancement
                Toggle(isOn: $manager.configuration.enhancementEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enhance with AI")
                            .font(.body)
                        Text("Use GPT-4o-mini to improve transcription before insertion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Show custom prompt options when enabled
                if manager.configuration.enhancementEnabled {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("System Prompt")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Reset to Default") {
                                customPrompt = PromptEnhancer.defaultSystemPrompt
                                manager.configuration.customEnhancementPrompt = nil
                            }
                            .buttonStyle(.link)
                            .controlSize(.small)
                            .disabled(manager.configuration.customEnhancementPrompt == nil)
                        }

                        TextEditor(text: $customPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .onChange(of: customPrompt) { _, newValue in
                                if newValue.isEmpty || newValue == PromptEnhancer.defaultSystemPrompt {
                                    manager.configuration.customEnhancementPrompt = nil
                                } else {
                                    manager.configuration.customEnhancementPrompt = newValue
                                }
                            }
                    }
                }
            }
            .padding(8)
        } label: {
            SectionHeader(title: "Prompt Enhancement", icon: "wand.and.stars")
        }
        .onAppear {
            // Initialize custom prompt from configuration or default
            customPrompt = manager.configuration.customEnhancementPrompt ?? PromptEnhancer.defaultSystemPrompt
        }
    }
}

// MARK: - Preview

#Preview {
    FloatingSTTSettingsView(manager: FloatingSTTManager())
}
#endif
