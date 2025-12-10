//
//  CodeWhisperSettingsSheet.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/29/25.
//

import AppKit
import SwiftUI

/// Settings sheet for CodeWhisper voice mode
/// Displayed on long-press of CodeWhisperButton
public struct CodeWhisperSettingsSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(MCPServerManager.self) private var mcpManager
  @Environment(\.dismiss) private var dismiss

  let configuration: CodeWhisperConfiguration

  public init(configuration: CodeWhisperConfiguration = .all) {
    self.configuration = configuration
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          if configuration.showVoiceModePicker {
            VoiceModeSection(availableModes: configuration.availableVoiceModes)
          }
          KeyboardShortcutSection()
          #if os(macOS)
          FloatingSTTSection()
          #endif
          if needsTTSSettings {
            TTSSettingsSection()
          }
          if needsRealtimeLanguageSettings {
            RealtimeLanguageSection()
          }
          APIKeySection()
          if needsClaudeCodeSettings {
            WorkingDirectorySection()
            MCPServersSection()
          }
          DangerZoneSection()
        }
        .padding(24)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(NSColor.windowBackgroundColor))
      .navigationTitle("Voice Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .frame(minWidth: 480, idealWidth: 520, minHeight: 400, idealHeight: 450)
  }

  // MARK: - Computed Properties

  /// TTS settings needed for Voice Chat or Realtime modes
  private var needsTTSSettings: Bool {
    configuration.availableVoiceModes.contains(.sttWithTTS) ||
    configuration.availableVoiceModes.contains(.realtime)
  }

  /// Claude Code settings needed only for Realtime mode
  private var needsClaudeCodeSettings: Bool {
    configuration.availableVoiceModes.contains(.realtime)
  }

  /// Realtime language settings needed only for Realtime mode
  private var needsRealtimeLanguageSettings: Bool {
    configuration.availableVoiceModes.contains(.realtime)
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
    } label: {
      SectionHeader(title: "Keyboard Shortcut", icon: "command")
    }
  }
}

// MARK: - Floating STT Section (macOS only)

#if os(macOS)
private struct FloatingSTTSection: View {
  @Environment(SettingsManager.self) private var settings
  @State private var hasAccessibilityPermission: Bool = false

  var body: some View {
    @Bindable var settings = settings

    GroupBox {
      VStack(alignment: .leading, spacing: 16) {
        // Floating button toggle
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Floating Voice Button")
              .font(.body)
            Text("Show a floating button for voice input in any app")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Toggle("", isOn: Binding(
            get: { FloatingSTT.isVisible },
            set: { newValue in
              if newValue {
                // Configure with SettingsManager before showing
                FloatingSTT.configure(settingsManager: settings)
                FloatingSTT.show()
              } else {
                FloatingSTT.hide()
              }
            }
          ))
          .labelsHidden()
        }

        Divider()

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

        Divider()

        // Button size slider
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Button Size")
              .font(.body)
            Spacer()
            Text("\(Int(settings.floatingSTTConfiguration.buttonWidth))×\(Int(settings.floatingSTTConfiguration.buttonHeight))pt")
              .font(.caption)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }

          Slider(
            value: $settings.floatingSTTConfiguration.buttonWidth,
            in: 60...100,
            step: 4
          ) {
            Text("Width")
          }
          .onChange(of: settings.floatingSTTConfiguration.buttonWidth) { _, newWidth in
            // Keep aspect ratio ~1.6:1 (horizontal capsule)
            settings.floatingSTTConfiguration.buttonHeight = newWidth * 0.6
          }
        }

        // Text insertion method
        HStack {
          Text("Insertion Method")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          Picker("", selection: $settings.floatingSTTConfiguration.preferredInsertionMethod) {
            Text("Accessibility API").tag(TextInsertionMethod.accessibilityAPI)
            Text("Clipboard").tag(TextInsertionMethod.clipboardPaste)
          }
          .labelsHidden()
          .frame(width: 160)
        }

        // Footer text
        Text("The floating button lets you dictate text into any app. Tap to record, tap again to insert.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    } label: {
      SectionHeader(title: "Floating Voice Button", icon: "bubble.left.and.bubble.right")
    }
    .onAppear {
      refreshPermission()
    }
  }

  private func refreshPermission() {
    hasAccessibilityPermission = FloatingSTT.hasAccessibilityPermission
  }
}
#endif

// MARK: - Voice Mode Section

private struct VoiceModeSection: View {
  @Environment(SettingsManager.self) private var settings
  let availableModes: [VoiceMode]

  var body: some View {
    GroupBox {
      VStack(spacing: 8) {
        ForEach(availableModes, id: \.self) { mode in
          VoiceModeOptionRow(
            mode: mode,
            isSelected: settings.selectedVoiceMode == mode,
            onSelect: { settings.selectedVoiceMode = mode }
          )
        }
      }
    } label: {
      SectionHeader(title: "Voice Mode", icon: "waveform")
    }
  }
}

private struct VoiceModeOptionRow: View {
  let mode: VoiceMode
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 12) {
        Image(systemName: mode.iconName)
          .font(.system(size: 20))
          .foregroundStyle(isSelected ? .white : .secondary)
          .frame(width: 32, height: 32)
          .background(isSelected ? Color.accentColor : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 6))

        VStack(alignment: .leading, spacing: 2) {
          Text(mode.displayName)
            .font(.body)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(.primary)
          Text(mode.description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentColor)
            .font(.system(size: 18))
        }
      }
      .padding(10)
      .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - TTS Settings Section

private struct TTSSettingsSection: View {
  @Environment(SettingsManager.self) private var settings

  var body: some View {
    @Bindable var settings = settings

    GroupBox {
      VStack(alignment: .leading, spacing: 16) {
        // Provider Picker
        VStack(alignment: .leading, spacing: 8) {
          Text("Provider")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Picker("", selection: $settings.ttsProvider) {
            ForEach(TTSProvider.allCases, id: \.self) { provider in
              Text(provider.displayName).tag(provider)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }

        if settings.ttsProvider == .openAI {
          Divider()

          // Voice Picker
          HStack {
            Text("Voice")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $settings.openAITTSVoice) {
              ForEach(OpenAITTSVoice.allCases, id: \.self) { voice in
                Text(voice.displayName).tag(voice)
              }
            }
            .labelsHidden()
            .frame(width: 140)
          }

          // Quality Picker
          HStack {
            Text("Quality")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $settings.openAITTSModel) {
              ForEach(OpenAITTSModel.allCases, id: \.self) { model in
                Text(model.displayName).tag(model)
              }
            }
            .labelsHidden()
            .frame(width: 140)
          }
        }

        // Footer text
        Text(settings.ttsProvider == .apple
          ? "Apple TTS works offline and is free."
          : "OpenAI TTS provides natural-sounding voices.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    } label: {
      SectionHeader(title: "Text-to-Speech", icon: "speaker.wave.2")
    }
  }
}

// MARK: - Realtime Language Section

private struct RealtimeLanguageSection: View {
  @Environment(SettingsManager.self) private var settings
  @State private var customLanguageCode: String = ""
  @State private var isCustomSelected: Bool = false

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        // Language picker
        HStack {
          Text("Language")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          Picker("", selection: Binding(
            get: { pickerSelection },
            set: { handlePickerChange($0) }
          )) {
            ForEach(RealtimeLanguage.presets, id: \.rawValue) { language in
              Text(language.displayName).tag(language.rawValue)
            }
            Text("Custom").tag("custom")
          }
          .labelsHidden()
          .frame(width: 140)
        }

        // Custom input field
        if isCustomSelected {
          HStack {
            Text("ISO-639-1 Code")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            TextField("e.g., de, pt, ko", text: $customLanguageCode)
              .textFieldStyle(.roundedBorder)
              .frame(width: 100)
              .onChange(of: customLanguageCode) { _, newValue in
                let cleaned = newValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count <= 3 {
                  settings.realtimeLanguage = .custom(cleaned)
                }
              }
          }
        }

        // Footer text
        Text("Improves transcription accuracy and reduces latency.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    } label: {
      SectionHeader(title: "Transcription Language", icon: "globe")
    }
    .onAppear {
      if case .custom(let code) = settings.realtimeLanguage {
        customLanguageCode = code
        isCustomSelected = true
      }
    }
  }

  private var pickerSelection: String {
    if case .custom = settings.realtimeLanguage {
      return "custom"
    }
    return settings.realtimeLanguage.rawValue
  }

  private func handlePickerChange(_ newValue: String) {
    if newValue == "custom" {
      isCustomSelected = true
      settings.realtimeLanguage = .custom(customLanguageCode)
    } else if let language = RealtimeLanguage(rawValue: newValue) {
      isCustomSelected = false
      customLanguageCode = ""
      settings.realtimeLanguage = language
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
    } label: {
      SectionHeader(title: "OpenAI API Key", icon: "key")
    }
  }
}

// MARK: - Working Directory Section

private struct WorkingDirectorySection: View {
  @Environment(SettingsManager.self) private var settings

  var body: some View {
    @Bindable var settings = settings

    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        if settings.workingDirectory.isEmpty {
          // No directory selected
          VStack(alignment: .leading, spacing: 8) {
            Text("No directory selected")
              .font(.body)
              .foregroundStyle(.secondary)

            Button {
              showDirectoryPicker()
            } label: {
              Label("Choose Directory", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
          }
        } else {
          // Directory is set
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
              Image(systemName: "folder.fill")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 16))

              VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: settings.workingDirectory).lastPathComponent)
                  .font(.body)
                  .fontWeight(.medium)
                Text(settings.workingDirectory)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .truncationMode(.middle)
              }

              Spacer()

              Button("Change") {
                showDirectoryPicker()
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
            }

            Divider()

            Toggle(isOn: $settings.bypassPermissions) {
              VStack(alignment: .leading, spacing: 2) {
                Text("Bypass Permissions")
                  .font(.body)
                Text("Execute operations without confirmation")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
    } label: {
      SectionHeader(title: "Claude Code", icon: "terminal")
    }
  }

  private func showDirectoryPicker() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    panel.message = "Select working directory for Claude Code"
    panel.prompt = "Select"

    if panel.runModal() == .OK {
      if let url = panel.url {
        settings.setWorkingDirectory(url.path)
      }
    }
  }
}

// MARK: - MCP Servers Section

private struct MCPServersSection: View {
  @Environment(MCPServerManager.self) private var mcpManager

  var body: some View {
    GroupBox {
      NavigationLink {
        MCPSettingsView()
      } label: {
        HStack {
          Image(systemName: "server.rack")
            .foregroundStyle(Color.accentColor)
            .font(.system(size: 20))
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 2) {
            Text("MCP Servers")
              .font(.body)
              .foregroundStyle(.primary)
            Text("Extend AI with external tools")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          if mcpManager.hasServers {
            Text("\(mcpManager.servers.count)")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(Color.accentColor)
              .clipShape(Capsule())
          }

          Image(systemName: "chevron.right")
            .foregroundStyle(.tertiary)
            .font(.system(size: 12, weight: .semibold))
        }
        .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
    } label: {
      SectionHeader(title: "Extensions", icon: "puzzlepiece.extension")
    }
  }
}

// MARK: - Danger Zone Section

private struct DangerZoneSection: View {
  @Environment(SettingsManager.self) private var settings

  var body: some View {
    GroupBox {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Clear API Key")
            .font(.body)
          Text("Remove stored API key from Keychain")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button(role: .destructive) {
          settings.clearAPIKey()
        } label: {
          Text("Clear")
        }
        .buttonStyle(.bordered)
        .disabled(!settings.hasValidAPIKey || settings.isUsingEnvironmentVariable)
      }
      .padding(.vertical, 4)
    } label: {
      Label {
        Text("Danger Zone")
          .font(.headline)
          .foregroundStyle(.primary)
      } icon: {
        Image(systemName: "exclamationmark.triangle")
          .foregroundStyle(.orange)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  CodeWhisperSettingsSheet()
    .environment(SettingsManager())
    .environment(MCPServerManager())
}
