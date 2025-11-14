//
//  SettingsView.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI

struct SettingsView: View {
  @Bindable var settingsManager: SettingsManager
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
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
  }
}

#Preview {
  SettingsView(settingsManager: SettingsManager())
}
