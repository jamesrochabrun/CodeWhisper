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
