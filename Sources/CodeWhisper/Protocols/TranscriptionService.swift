//
//  TranscriptionService.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 1/12/26.
//

import Foundation

public protocol TranscriptionService: Sendable {
  
  func transcribe(
    audioData: Data,
    fileName: String,
    model: String,
    responseFormat: String?)
    async throws -> TranscriptionResult
}

public struct TranscriptionResult: Sendable {
  
  public let text: String
  public let language: String?
  
  public init(text: String, language: String?) {
    self.text = text
    self.language = language
  }
}
