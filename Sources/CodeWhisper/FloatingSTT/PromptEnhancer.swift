//
//  PromptEnhancer.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/10/25.
//

#if os(macOS)
import Foundation
import Observation
import SwiftOpenAI

/// Service to enhance transcribed text using an LLM before insertion.
/// Uses GPT-4o-mini for fast, cost-effective text enhancement.
@Observable
@MainActor
public final class PromptEnhancer {

  // MARK: - Properties

  private var service: OpenAIService?
  private var chatService: ChatService?

  /// Default system prompt for enhancement
  public nonisolated static let defaultSystemPrompt = """
  You are a transcription enhancer. Your job is to:
  1. Fix any obvious transcription errors
  2. Add proper punctuation and formatting
  3. If the text is a command or instruction, format it clearly
  4. Keep the original meaning intact
  5. Return ONLY the enhanced text, no explanations
  """

  // MARK: - Initialization

  public init() {}

  // MARK: - Configuration

  /// Configure the enhancer with a SwiftOpenAI service
  public func configure(service: OpenAIService) {
    self.service = service
    self.chatService = nil
  }

  /// Configure the enhancer with a ChatService (supports SwiftAIKit)
  public func configure(chatService: ChatService) {
    self.chatService = chatService
    self.service = nil
  }

  // MARK: - Enhancement

  /// Enhance transcribed text using the LLM
  /// - Parameters:
  ///   - text: The raw transcribed text
  ///   - systemPrompt: The system prompt to guide enhancement
  /// - Returns: The enhanced text
  public func enhance(
    text: String,
    model: String,
    systemPrompt: String
  ) async throws -> String {
    // Skip enhancement for very short text
    guard text.count > 2 else {
      return text
    }

    // Use ChatService if available, otherwise fall back to SwiftOpenAI service
    if let chatService = chatService {
      return try await enhanceWithChatService(
        text: text,
        systemPrompt: systemPrompt,
        model: model,
        chatService: chatService
      )
    } else if let service = service {
      return try await enhanceWithSwiftOpenAI(
        text: text,
        systemPrompt: systemPrompt,
        service: service
      )
    } else {
      throw PromptEnhancerError.notConfigured
    }
  }

  private func enhanceWithChatService(
    text: String,
    systemPrompt: String,
    model: String,
    chatService: ChatService
  ) async throws -> String {
    let messages = [
      ChatMessage(role: .system, content: systemPrompt),
      ChatMessage(role: .user, content: text)
    ]

    let enhancedText = try await chatService.chat(
      messages: messages,
      model: model,
      maxTokens: 1024,
      temperature: 0.3
    )

    return enhancedText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func enhanceWithSwiftOpenAI(
    text: String,
    systemPrompt: String,
    service: OpenAIService
  ) async throws -> String {
    let parameters = ChatCompletionParameters(
      messages: [
        .init(role: .system, content: .text(systemPrompt)),
        .init(role: .user, content: .text(text))
      ],
      model: .gpt4omini,
      maxTokens: 1024,
      temperature: 0.3  // Low temperature for consistent output
    )

    let response = try await service.startChat(parameters: parameters)

    guard let enhancedText = response.choices?.first?.message?.content else {
      throw PromptEnhancerError.noContent
    }

    return enhancedText.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

// MARK: - Errors

public enum PromptEnhancerError: LocalizedError {
  case notConfigured
  case noContent

  public var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "PromptEnhancer is not configured with an OpenAI service"
    case .noContent:
      return "No content received from enhancement API"
    }
  }
}
#endif

