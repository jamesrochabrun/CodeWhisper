//
//  ConversationTranscriptView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/10/25.
//

import SwiftUI

public struct ConversationTranscriptView: View {
  let messages: [ConversationMessage]

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(messages.suffix(10).enumerated()), id: \.element.id) { index, message in
            StoryMessageView(message: message, index: index, total: min(messages.count, 10))
              .id(message.id)
              .transition(.opacity)
              .animation(.easeInOut(duration: 0.3), value: messages.count)
          }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
      }
      .onChange(of: messages.count) { _, _ in
        if let lastMessage = messages.last {
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.black.opacity(0.3))
  }
}

public struct StoryMessageView: View {
  let message: ConversationMessage
  let index: Int
  let total: Int

  private var opacity: Double {
    // Fade older messages more dramatically
    let position = Double(index) / Double(max(total - 1, 1))
    let exponentialPosition = pow(position, 1.5)
    return 0.4 + (exponentialPosition * 0.6) // Range from 0.4 to 1.0
  }

  private var messagePrefix: String {
    // User messages: no prefix
    // Assistant messages: bullet point
    // Claude Code messages: different indicators
    if message.isUser {
      return ""
    }

    switch message.messageType {
    case .claudeCodeStart:
      return "▸ "  // Triangle for Claude Code start
    case .claudeCodeProgress:
      return "  ▫︎ "  // Small square indented for progress
    case .claudeCodeResult:
      return "  ✓ "  // Checkmark for results
    case .claudeCodeError:
      return "  ✗ "  // X for errors
    case .regular:
      return "• "  // Bullet for regular assistant messages
    }
  }

  private var textColor: Color {
    switch message.messageType {
    case .claudeCodeStart:
      return .white  // White for consistency
    case .claudeCodeProgress:
      return .white  // White instead of light blue
    case .claudeCodeResult:
      return .white  // White instead of green
    case .claudeCodeError:
      return Color(red: 1.0, green: 0.4, blue: 0.4)  // Keep red for errors
    case .regular:
      return message.isUser ?
        Color(red: 0.7, green: 0.7, blue: 0.7) :  // Gray for user
        Color.white  // White for assistant
    }
  }

  private var shouldBeBold: Bool {
    // Bold text for Claude Code messages
    switch message.messageType {
    case .claudeCodeStart, .claudeCodeProgress, .claudeCodeResult:
      return false
    case .claudeCodeError, .regular:
      return false
    }
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 0) {
      // Prefix (bullet, etc.)
      if !messagePrefix.isEmpty {
        Text(messagePrefix)
          .font(.body)
          .foregroundStyle(textColor)
          .fontWeight(shouldBeBold ? .bold : .regular)
      }

      VStack(alignment: .leading, spacing: 6) {
        // Show image if present
        if let imageBase64URL = message.imageBase64URL,
           let image = decodeBase64Image(imageBase64URL) {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 200, maxHeight: 150)
            .cornerRadius(6)
            .padding(.vertical, 4)
        }

        // Message text
        Text(message.text)
          .font(.body)
          .foregroundStyle(textColor)
          .fontWeight(shouldBeBold ? .bold : .regular)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .opacity(opacity)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func decodeBase64Image(_ base64DataURL: String) -> NSImage? {
    // Extract base64 string from data URL
    // Format: "data:image/{format};base64,{base64_string}"
    guard let commaIndex = base64DataURL.firstIndex(of: ",") else {
      return nil
    }

    let base64String = String(base64DataURL[base64DataURL.index(after: commaIndex)...])
    guard let imageData = Data(base64Encoded: base64String) else {
      return nil
    }

    return NSImage(data: imageData)
  }
}

#Preview {
  let sampleMessages = [
    ConversationMessage(text: "Hello!", isUser: true, timestamp: Date()),
    ConversationMessage(text: "Hi there! How can I assist you today?", isUser: false, timestamp: Date()),
    ConversationMessage(text: "Can you help me with something?", isUser: true, timestamp: Date()),
    ConversationMessage(text: "Of course! I'd be happy to help. What do you need?", isUser: false, timestamp: Date()),
    ConversationMessage(
      text: "Executing Claude Code task",
      isUser: false,
      timestamp: Date(),
      messageType: .claudeCodeStart
    ),
    ConversationMessage(
      text: "Reading file: example.swift",
      isUser: false,
      timestamp: Date(),
      messageType: .claudeCodeProgress
    ),
    ConversationMessage(
      text: "Task completed successfully",
      isUser: false,
      timestamp: Date(),
      messageType: .claudeCodeResult
    )
  ]

  ConversationTranscriptView(messages: sampleMessages)
    .frame(height: 300)
    .background(Color.black)
}
