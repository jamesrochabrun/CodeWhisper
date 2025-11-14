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
    message.isUser ?
    Color(red: 0.2, green: 0.9, blue: 0.6) : // Cyan/green for user
    Color(red: 0.9, green: 0.5, blue: 1.0)   // Magenta for AI
  }
  
  private var labelColor: Color {
    message.isUser ?
    Color(red: 0.3, green: 1.0, blue: 0.7) :
    Color(red: 1.0, green: 0.6, blue: 1.0)
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
      Text(message.isUser ? "You" : "AI")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(labelColor)
      
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
    .frame(maxWidth: 250, alignment: message.isUser ? .leading : .trailing)
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
