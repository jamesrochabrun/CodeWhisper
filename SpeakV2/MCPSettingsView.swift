//
//  MCPSettingsView.swift
//  SpeakV2
//
//  MCP Server configuration UI
//

import SwiftUI

struct MCPSettingsView: View {
  @Environment(MCPServerManager.self) private var manager
  @State private var showingAddServer = false

  var body: some View {
    VStack(spacing: 20) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("MCP Servers")
            .font(.title2)
            .fontWeight(.semibold)

          Text("Configure Model Context Protocol servers for extended capabilities")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button {
          showingAddServer = true
        } label: {
          Label("Add Server", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.borderedProminent)
      }
      .padding()

      Divider()

      // Server List
      if manager.servers.isEmpty {
        ContentUnavailableView {
          Label("No MCP Servers", systemImage: "server.rack")
        } description: {
          Text("Add an MCP server to extend your AI assistant with external tools and capabilities")
        } actions: {
          Button("Add Server") {
            showingAddServer = true
          }
          .buttonStyle(.borderedProminent)

          Button("Add Sample Server") {
            manager.addSampleServer()
          }
          .buttonStyle(.bordered)
        }
        .frame(maxHeight: .infinity)
      } else {
        List {
          ForEach(manager.servers) { server in
            MCPServerRow(server: server)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                  manager.deleteServer(server)
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
          }
          .onDelete(perform: manager.deleteServers)
        }
      }
    }
    .sheet(isPresented: $showingAddServer) {
      MCPServerEditView()
    }
  }
}

// MARK: - Server Row

struct MCPServerRow: View {
  let server: MCPServerConfig
  @State private var showingEdit = false

  var body: some View {
    HStack(spacing: 12) {
      // Icon
      Image(systemName: "server.rack")
        .font(.title2)
        .foregroundStyle(.blue)
        .frame(width: 40)

      // Info
      VStack(alignment: .leading, spacing: 4) {
        Text(server.label)
          .font(.headline)

        Text(server.serverUrl)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)

        HStack(spacing: 8) {
          Label(server.requireApproval, systemImage: "checkmark.shield")
            .font(.caption2)
            .foregroundStyle(.secondary)

          if server.authorization != nil {
            Label("Authenticated", systemImage: "key.fill")
              .font(.caption2)
              .foregroundStyle(.green)
          }
        }
      }

      Spacer()

      // Edit button
      Button {
        showingEdit = true
      } label: {
        Image(systemName: "pencil.circle")
          .font(.title3)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .sheet(isPresented: $showingEdit) {
      MCPServerEditView(editingServer: server)
    }
  }
}

// MARK: - Server Edit View

struct MCPServerEditView: View {
  @Environment(MCPServerManager.self) private var manager
  @Environment(\.dismiss) private var dismiss

  let editingServer: MCPServerConfig?

  @State private var label: String
  @State private var serverUrl: String
  @State private var authorization: String
  @State private var requireApproval: String

  init(editingServer: MCPServerConfig? = nil) {
    self.editingServer = editingServer
    _label = State(initialValue: editingServer?.label ?? "")
    _serverUrl = State(initialValue: editingServer?.serverUrl ?? "")
    _authorization = State(initialValue: editingServer?.authorization ?? "")
    _requireApproval = State(initialValue: editingServer?.requireApproval ?? "never")
  }

  var isValid: Bool {
    !label.isEmpty && !serverUrl.isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Server Information") {
          TextField("Label (e.g., 'stripe')", text: $label)
            .textFieldStyle(.roundedBorder)

          TextField("Server URL", text: $serverUrl)
            .textFieldStyle(.roundedBorder)
#if !os(macOS)
            .autocapitalization(.none)
            .keyboardType(.URL)
#endif
        }

        Section("Authentication") {
          TextField("Authorization Token (optional)", text: $authorization)
            .textFieldStyle(.roundedBorder)
#if !os(macOS)
            .autocapitalization(.none)
#endif

          Text("OAuth access token for the MCP server")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("Approval Settings") {
          Picker("Require Approval", selection: $requireApproval) {
            Text("Never").tag("never")
            Text("Always").tag("always")
            Text("Filters").tag("filters")
          }
          .pickerStyle(.segmented)

          Text("Control when tool calls require approval")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      .navigationTitle(editingServer == nil ? "Add Server" : "Edit Server")
#if !os(macOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(editingServer == nil ? "Add" : "Save") {
            save()
          }
          .disabled(!isValid)
        }
      }
    }
    .frame(width: 500, height: 450)
  }

  private func save() {
    let config = MCPServerConfig(
      id: editingServer?.id ?? UUID(),
      label: label,
      serverUrl: serverUrl,
      authorization: authorization.isEmpty ? nil : authorization,
      requireApproval: requireApproval
    )

    if editingServer != nil {
      manager.updateServer(config)
    } else {
      manager.addServer(config)
    }

    dismiss()
  }
}

#Preview {
  MCPSettingsView()
    .environment(MCPServerManager())
    .frame(width: 600, height: 500)
}
