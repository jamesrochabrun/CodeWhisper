//
//  ClaudeCodeManager.swift
//  SpeakV2
//
//  Manages Claude Code SDK integration for voice-triggered coding tasks
//  Uses ChatViewModel from ClaudeCodeUI package
//

import Foundation
import Observation
import ClaudeCodeCore

/// Represents the current state of Claude Code execution
enum ClaudeCodeState {
  case idle
  case processing
  case completed
  case error(String)
}

/// Detailed progress information from Claude Code streaming
struct ClaudeCodeProgress: Identifiable, Equatable {
  let id = UUID()
  let type: ProgressType
  let content: String
  let timestamp: Date

  enum ProgressType: Equatable {
    case thinking
    case toolCall(name: String, parameters: String)
    case fileOperation(path: String, action: String)
    case result
    case error
  }

  static func == (lhs: ClaudeCodeProgress, rhs: ClaudeCodeProgress) -> Bool {
    lhs.id == rhs.id
  }
}

@Observable
@MainActor
final class ClaudeCodeManager {
  // Current state
  private(set) var state: ClaudeCodeState = .idle

  // Streaming progress updates
  private(set) var progressUpdates: [ClaudeCodeProgress] = []

  // Final result for AI to summarize
  private(set) var lastResult: String?

  // ChatViewModel from ClaudeCodeUI
  private var chatViewModel: ChatViewModel?

  // Stream cancellation
  private var currentTask: Task<Void, Never>?

  // MARK: - Initialization

  /// Initialize with an existing ChatViewModel from ClaudeCodeUI
  func initialize(chatViewModel: ChatViewModel) {
    self.chatViewModel = chatViewModel
    print("ClaudeCodeManager: Initialized with existing ChatViewModel")
  }

  // MARK: - Execution

  /// Execute a Claude Code task with streaming progress
  func executeTask(_ task: String) async throws -> String {
    guard let chatViewModel = chatViewModel else {
      print("❌ ClaudeCodeManager: Not initialized")
      throw ClaudeCodeError.notInitialized
    }

    print("🚀 ClaudeCodeManager: Executing task: \(task)")
    print("📊 ClaudeCodeManager: ChatViewModel isLoading: \(chatViewModel.isLoading)")
    print("📊 ClaudeCodeManager: Message count: \(chatViewModel.messages.count)")

    // Reset state
    state = .processing
    progressUpdates = []
    lastResult = nil

    // Cancel any existing task
    currentTask?.cancel()

    print("📤 ClaudeCodeManager: Sending message to ChatViewModel...")
    // Send message to Claude Code
    chatViewModel.sendMessage(
      task,
      context: nil,
      hiddenContext: nil,
      codeSelections: nil,
      attachments: nil
    )
    print("✅ ClaudeCodeManager: Message sent, isLoading: \(chatViewModel.isLoading)")

    // Monitor for completion
    currentTask = Task {
      print("⏳ ClaudeCodeManager: Starting monitoring loop...")
      // Wait for processing to complete by monitoring isLoading state
      // Poll every 500ms for up to 2 minutes
      var pollAttempts = 0
      let maxPollAttempts = 240 // 2 minutes with 0.5 second intervals

      while !Task.isCancelled && pollAttempts < maxPollAttempts {
        // Check if processing is complete
        if !chatViewModel.isLoading {
          // Completed
          print("✅ ClaudeCodeManager: Processing complete after \(pollAttempts) polls")
          print("📊 ClaudeCodeManager: Final message count: \(chatViewModel.messages.count)")
          await MainActor.run {
            self.state = .completed
            self.lastResult = self.generateResultSummary()
          }
          break
        }

        // Wait before next poll
        try? await Task.sleep(for: .milliseconds(500))
        pollAttempts += 1

        // Log every 10 attempts (every 5 seconds)
        if pollAttempts % 10 == 0 {
          print("⏳ ClaudeCodeManager: Still waiting... (\(pollAttempts) polls, isLoading: \(chatViewModel.isLoading), messages: \(chatViewModel.messages.count))")
        }
      }

      // Timeout check
      if pollAttempts >= maxPollAttempts {
        print("⏰ ClaudeCodeManager: Timeout after \(pollAttempts) polls")
        await MainActor.run {
          self.state = .error("Timeout")
          self.addProgress(.error, content: "Claude Code task timed out after 2 minutes")
          self.lastResult = "Error: Task timed out after 2 minutes"
        }
      }
    }

    // Wait for completion
    await currentTask?.value

    // Return final result
    guard let result = lastResult else {
      throw ClaudeCodeError.noResult
    }

    return result
  }

  // MARK: - Progress Tracking

  private func addProgress(_ type: ClaudeCodeProgress.ProgressType, content: String) {
    let progress = ClaudeCodeProgress(
      type: type,
      content: content,
      timestamp: Date()
    )
    progressUpdates.append(progress)
    print("ClaudeCodeManager Progress: \(content)")
  }

  private func generateResultSummary() -> String {
    guard let chatViewModel = chatViewModel else {
      return "Error: No ChatViewModel available"
    }

    // Get messages count and loading state as proxies for what happened
    let messageCount = chatViewModel.messages.count
    let hasMessages = messageCount > 0

    // Generate simple summary
    var summary = "Claude Code execution completed.\n\n"

    if hasMessages {
      summary += "Processed \(messageCount) message(s)\n"

      // Try to get the last assistant message text
      if let lastMessage = chatViewModel.messages.last(where: { $0.role == .assistant }) {
        let textContent = lastMessage.content

        if !textContent.isEmpty {
          summary += "\nResult: \(textContent)"
          addProgress(.result, content: textContent)
        }
      }
    } else {
      summary += "No messages generated"
    }

    return summary
  }

  // MARK: - Cleanup

  func cancel() {
    currentTask?.cancel()
    currentTask = nil
    chatViewModel?.cancelRequest()
    state = .idle
  }
}

// MARK: - Errors

enum ClaudeCodeError: LocalizedError {
  case notInitialized
  case noResult

  var errorDescription: String? {
    switch self {
    case .notInitialized:
      return "ClaudeCodeManager not initialized"
    case .noResult:
      return "No result from Claude Code execution"
    }
  }
}
