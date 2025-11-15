//
//  ConversationTranscriptView.swift
//  SpeakV2
//
//  Created by James Rochabrun on 11/10/25.
//

import SwiftUI

struct ConversationTranscriptView: View {
  let messages: [ConversationMessage]
  
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 12) {
          ForEach(Array(messages.suffix(5).enumerated()), id: \.element.id) { index, message in
            MessageBubble(message: message, index: index, total: min(messages.count, 5))
              .id(message.id)
              .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                removal: .opacity
              ))
              .animation(.spring(response: 0.5, dampingFraction: 0.7), value: messages.count)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
      }
      .onChange(of: messages.count) { _, _ in
        if let lastMessage = messages.last {
          withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .background(Color.black.opacity(0.3))
  }
}

struct MessageBubble: View {
  let message: ConversationMessage
  let index: Int
  let total: Int
  
  private var opacity: Double {
    // Newer messages are more opaque, older fade more dramatically
    let position = Double(index) / Double(max(total - 1, 1))
    // Use exponential curve for more dramatic fade
    let exponentialPosition = pow(position, 1.5)
    return 0.3 + (exponentialPosition * 0.7) // Range from 0.3 to 1.0
  }
  
  private var messageColor: Color {
    switch message.messageType {
    case .claudeCodeStart:
      return Color(red: 0.2, green: 0.6, blue: 1.0) // Blue for Claude Code start
    case .claudeCodeProgress:
      return Color(red: 0.4, green: 0.7, blue: 1.0) // Light blue for progress
    case .claudeCodeResult:
      return Color(red: 0.2, green: 1.0, blue: 0.6) // Green for success
    case .claudeCodeError:
      return Color(red: 1.0, green: 0.3, blue: 0.3) // Red for error
    case .regular:
      return message.isUser ?
        Color(red: 0.2, green: 0.9, blue: 0.6) : // Cyan/green for user
        Color(red: 0.9, green: 0.5, blue: 1.0)   // Magenta for AI
    }
  }

  private var labelColor: Color {
    switch message.messageType {
    case .claudeCodeStart, .claudeCodeProgress, .claudeCodeResult, .claudeCodeError:
      return Color(red: 0.4, green: 0.8, blue: 1.0) // Claude Code messages
    case .regular:
      return message.isUser ?
        Color(red: 0.3, green: 1.0, blue: 0.7) :
        Color(red: 1.0, green: 0.6, blue: 1.0)
    }
  }

  private var messageLabel: String {
    switch message.messageType {
    case .claudeCodeStart, .claudeCodeProgress, .claudeCodeResult, .claudeCodeError:
      return "Claude Code"
    case .regular:
      return message.isUser ? "You" : "AI"
    }
  }
  
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      if message.isUser {
        messageContent
        Spacer()
      } else {
        Spacer()
        messageContent
      }
    }
    .opacity(opacity)
  }
  
  private var messageContent: some View {
    VStack(alignment: message.isUser ? .leading : .trailing, spacing: 4) {
      Text(messageLabel)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(labelColor)
      
      VStack(alignment: message.isUser ? .leading : .trailing, spacing: 6) {
        // Show image if present
        if let imageBase64URL = message.imageBase64URL,
           let image = decodeBase64Image(imageBase64URL) {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 200, maxHeight: 150)
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(messageColor.opacity(0.4), lineWidth: 1)
            )
        }
        
        // Message text
        Text(message.text)
          .font(.body)
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(messageColor.opacity(0.2))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(messageColor.opacity(0.4), lineWidth: 1)
              )
          )
      }
    }
    .frame(maxWidth: 250, alignment: message.isUser ? .leading : .trailing)
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
    ConversationMessage(text: "Of course! I'd be happy to help. What do you need?", isUser: false, timestamp: Date())
  ]
  
  ConversationTranscriptView(messages: sampleMessages)
    .frame(height: 200)
    .background(Color.black)
}
