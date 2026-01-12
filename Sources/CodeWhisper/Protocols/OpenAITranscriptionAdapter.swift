//
//  OpenAITranscriptionAdapter.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 1/12/26.
//

import Foundation
import SwiftOpenAI

/// Adapter that bridges SwiftOpenAI's OpenAIService to the TranscriptionService protocol.
/// This allows FloatingSTTManager to work with both direct OpenAIService instances
/// and protocol-based TranscriptionService implementations.
public struct OpenAITranscriptionAdapter: TranscriptionService {
  
  private let service: OpenAIService
  
  public init(service: OpenAIService) {
    self.service = service
  }
  
  public func transcribe(
    audioData: Data,
    fileName: String,
    model: String,
    responseFormat: String?
  ) async throws -> TranscriptionResult {
    AppLogger.info("[OpenAITranscriptionAdapter] Starting transcription - model: \(model), fileName: \(fileName), dataSize: \(audioData.count) bytes")
    
    let parameters = AudioTranscriptionParameters(
      fileName: fileName,
      file: audioData
    )
    
    do {
      let response = try await service.createTranscription(parameters: parameters)
      AppLogger.info("[OpenAITranscriptionAdapter] Transcription successful, text length: \(response.text.count)")
      
      // Handle the optional language properly
      let language: String? = response.language
      return TranscriptionResult(text: response.text, language: language)
    } catch {
      AppLogger.error("[OpenAITranscriptionAdapter] Transcription failed: \(error.localizedDescription)")
      throw error
    }
  }
}
