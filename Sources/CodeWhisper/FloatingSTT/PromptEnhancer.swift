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

  /// Configure the enhancer with an OpenAI service
  public func configure(service: OpenAIService) {
    self.service = service
  }

  // MARK: - Enhancement

  /// Enhance transcribed text using the LLM
  /// - Parameters:
  ///   - text: The raw transcribed text
  ///   - systemPrompt: The system prompt to guide enhancement
  /// - Returns: The enhanced text
  public func enhance(
    text: String,
    systemPrompt: String
  ) async throws -> String {
    guard let service = service else {
      throw PromptEnhancerError.notConfigured
    }

    // Skip enhancement for very short text
    guard text.count > 2 else {
      return text
    }

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

    return enhancedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
