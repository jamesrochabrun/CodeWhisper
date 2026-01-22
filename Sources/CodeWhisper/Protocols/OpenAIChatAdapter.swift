//
//  OpenAIChatAdapter.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 1/22/26.
//

import Foundation
import SwiftOpenAI

/// Adapter that bridges SwiftOpenAI's OpenAIService to the ChatService protocol.
/// This allows PromptEnhancer and other components to work with both direct OpenAIService instances
/// and protocol-based ChatService implementations.
public struct OpenAIChatAdapter: ChatService {

  private let service: OpenAIService

  public init(service: OpenAIService) {
    self.service = service
  }

  public func chat(
    messages: [ChatMessage],
    model: String,
    maxTokens: Int?,
    temperature: Double?
  ) async throws -> String {
    AppLogger.debug("[OpenAIChatAdapter] Starting chat - model: \(model), messages: \(messages.count)")

    // Convert ChatMessage to SwiftOpenAI format
    let openAIMessages: [SwiftOpenAI.ChatCompletionParameters.Message] = messages.map { message in
      let role: SwiftOpenAI.ChatCompletionParameters.Message.Role = switch message.role {
      case .system: .system
      case .user: .user
      case .assistant: .assistant
      }
      return .init(role: role, content: .text(message.content))
    }

    // Map model string to SwiftOpenAI Model enum
    let openAIModel = mapModel(model)

    let parameters = ChatCompletionParameters(
      messages: openAIMessages,
      model: openAIModel,
      maxTokens: maxTokens,
      temperature: temperature
    )

    do {
      let response = try await service.startChat(parameters: parameters)

      guard let content = response.choices?.first?.message?.content else {
        AppLogger.error("[OpenAIChatAdapter] No content in response")
        throw OpenAIChatAdapterError.noContent
      }

      AppLogger.debug("[OpenAIChatAdapter] Chat successful, response length: \(content.count)")
      return content.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      AppLogger.error("[OpenAIChatAdapter] Chat failed: \(error.localizedDescription)")
      throw error
    }
  }

  /// Maps a model string to SwiftOpenAI's Model enum
  private func mapModel(_ model: String) -> SwiftOpenAI.Model {
    switch model.lowercased() {
    case "gpt-4o": return .gpt4o
    case "gpt-4o-mini": return .gpt4omini
    case "gpt-4": return .gpt4
    case "gpt-3.5-turbo": return .gpt35Turbo
    case "o1-mini": return .o1Mini
    case "o1-preview": return .o1Preview
    default: return .custom(model)
    }
  }
}

// MARK: - Errors

public enum OpenAIChatAdapterError: LocalizedError {
  case noContent

  public var errorDescription: String? {
    switch self {
    case .noContent:
      return "No content received from OpenAI chat API"
    }
  }
}
