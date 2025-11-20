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
    @Bindable var settingsManager = settings

    NavigationStack {
      Form {
        Section {
          if settingsManager.isUsingEnvironmentVariable {
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
          } else {
            VStack(alignment: .leading, spacing: 8) {
              SecureField("Enter your OpenAI API Key", text: $settingsManager.apiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
#if !os(macOS)
                .textInputAutocapitalization(.never)
#endif

              if settingsManager.hasValidAPIKey {
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
        } header: {
          Text("OpenAI Configuration")
        } footer: {
          VStack(alignment: .leading, spacing: 4) {
            Text("Your API key is stored securely in the system Keychain and only used to authenticate with OpenAI's Realtime API.")
            Text("Alternatively, set the OPENAI_API_KEY environment variable before launching the app.")
          }
          .font(.caption)
        }

        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Working Directory")
              .font(.headline)

            Text(settingsManager.workingDirectory)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .truncationMode(.middle)
              .textSelection(.enabled)

            Button("Choose Directory") {
              showDirectoryPicker()
            }
          }
          .padding(.vertical, 4)

          Toggle("Bypass Permissions", isOn: $settingsManager.bypassPermissions)
        } header: {
          Text("Claude Code")
        } footer: {
          Text("Select the directory where Claude Code will execute commands and access files. When bypass permissions is enabled, Claude Code will execute all operations without asking for confirmation. Use with caution.")
            .font(.caption)
        }

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

        Section {
          Button(role: .destructive) {
            settingsManager.clearAPIKey()
          } label: {
            Text("Clear API Key")
          }
          .disabled(!settingsManager.hasValidAPIKey || settingsManager.isUsingEnvironmentVariable)
        } footer: {
          if settingsManager.isUsingEnvironmentVariable {
            Text("Cannot clear API key when using environment variable")
              .font(.caption)
          }
        }
      }
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

#Preview {
  SettingsView()
    .environment(SettingsManager())
}
