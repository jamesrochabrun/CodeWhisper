//
//  SettingsView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI
import AppKit

public struct SettingsView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(MCPServerManager.self) private var mcpManager
  @Environment(\.dismiss) private var dismiss

  public var body: some View {
    NavigationStack {
      Form {
        APIKeySection()
        WorkingDirectorySection()
        VoiceModeSection()
        RealtimeVoiceSettingsSection()
        TTSSettingsSection()
        MCPServersSection()
        DangerZoneSection()
      }
      .padding(.horizontal)
      .navigationTitle("Settings")
#if !os(macOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .frame(minWidth: 900, minHeight: 400)
  }
}

// MARK: - API Key Section

private struct APIKeySection: View {
  @Environment(SettingsManager.self) private var settings
  
  var body: some View {
    // https://livsycode.com/swiftui/how-to-create-a-binding-to-a-property-of-an-environment-object-in-swiftui/
    @Bindable var settings = settings
    Section {
      if settings.isUsingEnvironmentVariable {
        EnvironmentVariableRow()
      } else {
        APIKeyInputRow(apiKey: $settings.apiKey, hasValidKey: settings.hasValidAPIKey)
      }
    } header: {
      Text("OpenAI Configuration")
    } footer: {
      VStack(alignment: .leading, spacing: 4) {
        Text("Your API key is stored securely in the system Keychain and only used to authenticate with OpenAI's Realtime API.")
        Text("Alternatively, set the OPENAI_API_KEY environment variable before launching the app.")
      }
      .font(.caption)
    }
  }
}

private struct EnvironmentVariableRow: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "checkmark.shield.fill")
          .foregroundStyle(.green)
        Text("API Key Loaded from Environment")
          .font(.headline)
      }
      
      Text("Using OPENAI_API_KEY environment variable")
        .font(.caption)
        .foregroundStyle(.secondary)
      
      Text("To change the key, update your environment variable and restart the app.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 8)
  }
}

private struct APIKeyInputRow: View {
  @Binding var apiKey: String
  let hasValidKey: Bool
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Enter your OpenAI API Key")
        .font(.headline)
      SecureField("", text: $apiKey)
        .textContentType(.password)
        .autocorrectionDisabled()
#if !os(macOS)
        .textInputAutocapitalization(.never)
#endif
      
      if hasValidKey {
        HStack {
          Image(systemName: "lock.shield.fill")
            .foregroundStyle(.blue)
            .font(.caption)
          Text("Stored securely in Keychain")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

// MARK: - Working Directory Section

private struct WorkingDirectorySection: View {
  @Environment(SettingsManager.self) private var settings
  
  var body: some View {
    @Bindable var settings = settings
    
    Section {
      WorkingDirectoryRow(
        workingDirectory: settings.workingDirectory,
        onChooseDirectory: showDirectoryPicker
      )
      
      Toggle("Bypass Permissions", isOn: $settings.bypassPermissions)
    } header: {
      Text("Claude Code")
    } footer: {
      Text("Select the directory where Claude Code will execute commands and access files. When bypass permissions is enabled, Claude Code will execute all operations without asking for confirmation. Use with caution.")
        .font(.caption)
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

private struct WorkingDirectoryRow: View {
  let workingDirectory: String
  let onChooseDirectory: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Working Directory")
        .font(.headline)
      
      Text(workingDirectory)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .truncationMode(.middle)
        .textSelection(.enabled)
      
      Button("Choose Directory") {
        onChooseDirectory()
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Voice Mode Section

private struct VoiceModeSection: View {
  @Environment(SettingsManager.self) private var settings

  var body: some View {
    @Bindable var settings = settings

    Section {
      ForEach(VoiceMode.allCases, id: \.self) { mode in
        VoiceModeRow(
          mode: mode,
          isSelected: settings.selectedVoiceMode == mode,
          onSelect: { settings.selectedVoiceMode = mode }
        )
      }
    } header: {
      Text("Voice Mode")
    } footer: {
      Text("Select your preferred voice interaction style. This will be used when you tap the voice button.")
        .font(.caption)
    }
  }
}

private struct VoiceModeRow: View {
  let mode: VoiceMode
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack {
        Image(systemName: mode.iconName)
          .foregroundStyle(isSelected ? .blue : .secondary)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(mode.displayName)
            .foregroundStyle(.primary)
          Text(mode.description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark")
            .foregroundStyle(.blue)
            .fontWeight(.semibold)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Realtime Voice Settings Section

private struct RealtimeVoiceSettingsSection: View {
  @Environment(SettingsManager.self) private var settings
  @State private var customLanguageCode: String = ""
  @State private var showCustomInput: Bool = false

  var body: some View {
    @Bindable var settings = settings

    Section {
      ForEach(RealtimeLanguage.presets, id: \.rawValue) { language in
        LanguageRow(
          language: language,
          isSelected: isLanguageSelected(language),
          onSelect: { selectLanguage(language) }
        )
      }

      // Custom language option
      VStack(alignment: .leading, spacing: 8) {
        Button(action: { toggleCustomInput() }) {
          HStack {
            Image(systemName: "character.textbox")
              .foregroundStyle(showCustomInput ? .blue : .secondary)
              .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
              Text("Custom")
                .foregroundStyle(.primary)
              Text("Enter ISO-639-1 code")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if case .custom = settings.realtimeLanguage {
              Image(systemName: "checkmark")
                .foregroundStyle(.blue)
                .fontWeight(.semibold)
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if showCustomInput {
          HStack {
            TextField("e.g., de, pt, ko", text: $customLanguageCode)
              .textFieldStyle(.roundedBorder)
              .frame(maxWidth: 120)
              .onChange(of: customLanguageCode) { _, newValue in
                let cleaned = newValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count <= 3 {
                  settings.realtimeLanguage = .custom(cleaned)
                }
              }

            if !customLanguageCode.isEmpty {
              Text("(\(customLanguageCode))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.leading, 32)
        }
      }
    } header: {
      Text("Realtime Voice")
    } footer: {
      Text("Set the transcription language to improve accuracy and reduce latency. Use ISO-639-1 codes (e.g., \"de\" for German, \"pt\" for Portuguese).")
        .font(.caption)
    }
    .onAppear {
      // Initialize custom input state
      if case .custom(let code) = settings.realtimeLanguage {
        customLanguageCode = code
        showCustomInput = true
      }
    }
  }

  private func isLanguageSelected(_ language: RealtimeLanguage) -> Bool {
    settings.realtimeLanguage == language
  }

  private func selectLanguage(_ language: RealtimeLanguage) {
    settings.realtimeLanguage = language
    showCustomInput = false
    customLanguageCode = ""
  }

  private func toggleCustomInput() {
    showCustomInput = true
    if case .custom(let code) = settings.realtimeLanguage {
      customLanguageCode = code
    } else {
      settings.realtimeLanguage = .custom(customLanguageCode)
    }
  }
}

private struct LanguageRow: View {
  let language: RealtimeLanguage
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack {
        Image(systemName: "globe")
          .foregroundStyle(isSelected ? .blue : .secondary)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(language.displayName)
            .foregroundStyle(.primary)
          if let code = language.code {
            Text(code)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark")
            .foregroundStyle(.blue)
            .fontWeight(.semibold)
        }
      }
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

    Section {
      // Provider Picker
      Picker("Provider", selection: $settings.ttsProvider) {
        ForEach(TTSProvider.allCases, id: \.self) { provider in
          Text(provider.displayName).tag(provider)
        }
      }
      .pickerStyle(.segmented)

      // OpenAI-specific settings
      if settings.ttsProvider == .openAI {
        Picker("Voice", selection: $settings.openAITTSVoice) {
          ForEach(OpenAITTSVoice.allCases, id: \.self) { voice in
            Text(voice.displayName).tag(voice)
          }
        }

        Picker("Quality", selection: $settings.openAITTSModel) {
          ForEach(OpenAITTSModel.allCases, id: \.self) { model in
            Text(model.displayName).tag(model)
          }
        }
      }
    } header: {
      Text("Text-to-Speech")
    } footer: {
      VStack(alignment: .leading, spacing: 4) {
        if settings.ttsProvider == .apple {
          Text("Apple TTS works offline and is free, but voices are less natural.")
        } else {
          Text("OpenAI TTS provides natural-sounding voices but requires an API key and incurs costs.")
        }
      }
      .font(.caption)
    }
  }
}

// MARK: - MCP Servers Section

private struct MCPServersSection: View {
  @Environment(MCPServerManager.self) private var mcpManager
  
  var body: some View {
    Section {
      NavigationLink {
        MCPSettingsView()
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text("MCP Servers")
            if mcpManager.hasServers {
              Text("\(mcpManager.servers.count) configured")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        } icon: {
          Image(systemName: "server.rack")
            .foregroundStyle(.blue)
        }
      }
    } header: {
      Text("Extensions")
    } footer: {
      Text("Configure Model Context Protocol servers to extend your AI assistant with external tools and capabilities.")
        .font(.caption)
    }
  }
}

// MARK: - Danger Zone Section

private struct DangerZoneSection: View {
  @Environment(SettingsManager.self) private var settings
  
  var body: some View {
    Section {
      Button(role: .destructive) {
        settings.clearAPIKey()
      } label: {
        Text("Clear API Key")
      }
      .disabled(!settings.hasValidAPIKey || settings.isUsingEnvironmentVariable)
    } footer: {
      if settings.isUsingEnvironmentVariable {
        Text("Cannot clear API key when using environment variable")
          .font(.caption)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  SettingsView()
    .environment(SettingsManager())
    .environment(MCPServerManager())
}
