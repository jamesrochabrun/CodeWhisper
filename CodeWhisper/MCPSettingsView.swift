//
//  MCPSettingsView.swift
//  CodeWhisper
//
//  MCP Server configuration UI
//

import SwiftUI

struct MCPSettingsView: View {
  @Environment(MCPServerManager.self) private var manager
  @State private var showingAddServer = false
  
  var body: some View {
    VStack(spacing: 0) {
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
      
      // Always show list (even if empty)
      List {
        if manager.servers.isEmpty {
          // Inline empty state
          VStack(spacing: 16) {
            Image(systemName: "server.rack")
              .font(.system(size: 48))
              .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
              Text("No MCP Servers")
                .font(.headline)
              
              Text("Add an MCP server to extend your AI assistant with external tools and capabilities")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
              Button("Add Server") {
                showingAddServer = true
              }
              .buttonStyle(.borderedProminent)
              
              Button("Add Sample Server") {
                manager.addSampleServer()
              }
              .buttonStyle(.bordered)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 40)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        } else {
          // Server list with section header
          Section {
            ForEach(manager.servers) { server in
              MCPServerRow(server: server)
            }
          } header: {
            HStack {
              Text("\(manager.servers.count) Server\(manager.servers.count == 1 ? "" : "s")")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
              
              Spacer()
              
              // Connection status summary (placeholder)
              Label("Not connected", systemImage: "bolt.slash")
                .font(.caption2)
                .foregroundStyle(.orange)
            }
          }
        }
      }
      .listStyle(.inset)
    }
    .sheet(isPresented: $showingAddServer) {
      MCPServerEditView()
    }
  }
}

// MARK: - Server Row

struct MCPServerRow: View {
  let server: MCPServerConfig
  @Environment(MCPServerManager.self) private var manager
  @State private var showingEdit = false
  @State private var showingDeleteConfirmation = false

  var body: some View {
    HStack(spacing: 12) {
      // Status indicator (placeholder)
      Circle()
        .fill(Color.orange)
        .frame(width: 8, height: 8)

      // Icon
      Image(systemName: "server.rack")
        .font(.title2)
        .foregroundStyle(.blue)
        .frame(width: 36)

      // Info (tappable to edit)
      Button {
        showingEdit = true
      } label: {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(server.label)
              .font(.headline)
              .foregroundColor(.primary)

            Spacer()

            // Connection status badge
            HStack(spacing: 4) {
              Image(systemName: "bolt.slash")
                .font(.caption2)
              Text("Not connected")
                .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.1))
            .foregroundStyle(.orange)
            .cornerRadius(4)
          }

          Text(server.serverUrl)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)

          // Details row
          HStack(spacing: 12) {
            // Auth status
            HStack(spacing: 4) {
              Image(systemName: server.authorization != nil ? "key.fill" : "key.slash")
                .font(.caption2)
              Text(server.authorization != nil ? "Authenticated" : "No auth")
                .font(.caption2)
            }
            .foregroundStyle(server.authorization != nil ? .green : .secondary)

            Divider()
              .frame(height: 12)

            // Approval setting
            HStack(spacing: 4) {
              Image(systemName: "checkmark.shield")
                .font(.caption2)
              Text("Approval: \(server.requireApproval)")
                .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Divider()
              .frame(height: 12)

            // Tools placeholder
            HStack(spacing: 4) {
              Image(systemName: "wrench.and.screwdriver")
                .font(.caption2)
              Text("? tools")
                .font(.caption2)
            }
            .foregroundStyle(.secondary)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Spacer()

      // Action buttons
      HStack(spacing: 8) {
        // Duplicate button
        Button {
          var duplicate = server
          duplicate.id = UUID()
          duplicate.label = "\(server.label) Copy"
          manager.addServer(duplicate)
        } label: {
          Image(systemName: "doc.on.doc")
            .font(.title3)
            .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .help("Duplicate server")

        // Delete button
        Button {
          showingDeleteConfirmation = true
        } label: {
          Image(systemName: "trash")
            .font(.title3)
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .help("Delete server")
      }
    }
    .padding(.vertical, 4)
    .sheet(isPresented: $showingEdit) {
      MCPServerEditView(editingServer: server)
    }
    .confirmationDialog("Delete Server", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
      Button("Delete", role: .destructive) {
        manager.deleteServer(server)
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Are you sure you want to delete '\(server.label)'? This action cannot be undone.")
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
  @State private var showValidationError = false
  @State private var validationMessage = ""
  
  init(editingServer: MCPServerConfig? = nil) {
    self.editingServer = editingServer
    _label = State(initialValue: editingServer?.label ?? "")
    _serverUrl = State(initialValue: editingServer?.serverUrl ?? "")
    _authorization = State(initialValue: editingServer?.authorization ?? "")
    _requireApproval = State(initialValue: editingServer?.requireApproval ?? "never")
  }
  
  var isValid: Bool {
    !label.isEmpty && !serverUrl.isEmpty && isValidUrl
  }
  
  var isValidUrl: Bool {
    serverUrl.isEmpty || serverUrl.hasPrefix("https://") || serverUrl.hasPrefix("http://")
  }
  
  var isDuplicateLabel: Bool {
    // Check for duplicate label (excluding current server when editing)
    manager.servers.contains { existingServer in
      existingServer.label == label && existingServer.id != editingServer?.id
    }
  }
  
  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 4) {
            TextField("Label (e.g., 'stripe')", text: $label)
              .textFieldStyle(.roundedBorder)
            
            if isDuplicateLabel {
              Label("A server with this label already exists", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            }
          }
          
          VStack(alignment: .leading, spacing: 4) {
            TextField("Server URL", text: $serverUrl)
              .textFieldStyle(.roundedBorder)
#if !os(macOS)
              .autocapitalization(.none)
              .keyboardType(.URL)
#endif
            
            if !serverUrl.isEmpty && !isValidUrl {
              Label("URL must start with https:// or http://", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
            }
            
            Text("The full URL to your MCP server endpoint (e.g., https://mcp.example.com/sse)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Server Information")
        }
        
        Section {
          VStack(alignment: .leading, spacing: 4) {
            TextField("Authorization Token (optional)", text: $authorization)
              .textFieldStyle(.roundedBorder)
#if !os(macOS)
              .autocapitalization(.none)
#endif
            
            if !authorization.isEmpty {
              HStack {
                Image(systemName: "info.circle")
                  .font(.caption2)
                Text("\(authorization.count) characters")
                  .font(.caption2)
              }
              .foregroundStyle(.secondary)
            }
          }
          
          Text("OAuth access token or API key for authenticating with the MCP server")
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
          Text("Authentication")
        }
        
        Section {
          Picker("Require Approval", selection: $requireApproval) {
            Text("Never").tag("never")
            Text("Always").tag("always")
            Text("Filters").tag("filters")
          }
          .pickerStyle(.segmented)
          
          Text(approvalDescription)
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
          Text("Approval Settings")
        }
        
        // Test connection section (placeholder)
        Section {
          Button {
            // TODO: Implement connection test
            showValidationError = true
            validationMessage = "Connection testing not yet implemented"
          } label: {
            HStack {
              Image(systemName: "network")
              Text("Test Connection")
              Spacer()
              Image(systemName: "arrow.right")
                .font(.caption)
            }
          }
          .disabled(true) // Enable when implemented
          
          Text("Verify that the server is reachable and responding")
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
          Text("Validation")
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
          .disabled(!isValid || isDuplicateLabel)
        }
      }
      .alert("Validation Error", isPresented: $showValidationError) {
        Button("OK") { }
      } message: {
        Text(validationMessage)
      }
    }
    .frame(width: 800, height: 550)
  }
  
  private var approvalDescription: String {
    switch requireApproval {
    case "never":
      return "Tools can execute without user approval (fastest, least secure)"
    case "always":
      return "All tool calls require user approval before execution (safest)"
    case "filters":
      return "Use custom filters to determine which tools require approval"
    default:
      return "Control when tool calls require approval"
    }
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
    .frame(width: 800, height: 500)
}
