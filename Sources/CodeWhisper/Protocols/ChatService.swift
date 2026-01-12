//
//  ChatService.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 1/12/26.
//

import Foundation

public protocol ChatService: Sendable {
  
  func chat(
    messages: [ChatMessage],
    model: String,
    maxTokens: Int?,
    temperature: Double?)
    async throws -> String
}


public struct ChatMessage: Sendable {
  
  public let role: ChatRole
  public let content: String
  
  public init(role: ChatRole, content: String) {
    self.role = role
    self.content = content
  }
}

public enum ChatRole: String, Sendable {
  case system
  case user
  case assistant
}
