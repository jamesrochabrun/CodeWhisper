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
          TTSSettingsSection()
          APIKeySection()
          WorkingDirectorySection()
          MCPServersSection()
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
    .frame(minWidth: 480, idealWidth: 520, minHeight: 700, idealHeight: 750)
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
