//
//  SettingsView.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

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
}

#Preview {
  SettingsView()
    .environment(SettingsManager())
}
