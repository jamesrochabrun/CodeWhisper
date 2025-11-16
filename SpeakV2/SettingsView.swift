//
//  SettingsView.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI
import AppKit

struct SettingsView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(MCPServerManager.self) private var mcpManager
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    @Bindable var settingsManager = settings

    NavigationStack {
      Form {
        Section {
          SecureField("Enter your OpenAI API Key", text: $settingsManager.apiKey)
            .textContentType(.password)
            .autocorrectionDisabled()
#if !os(macOS)
            .textInputAutocapitalization(.never)
#endif
        } header: {
          Text("OpenAI Configuration")
        } footer: {
          Text("Your API key is stored locally and only used to authenticate with OpenAI's Realtime API.")
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
        } header: {
          Text("Claude Code")
        } footer: {
          Text("Select the directory where Claude Code will execute commands and access files.")
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
          .disabled(!settingsManager.hasValidAPIKey)
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
