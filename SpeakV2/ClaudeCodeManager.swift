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
enum ClaudeCodeState: Equatable {
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

    // Monitor for completion and stream progress using real-time observation
    currentTask = Task {
      print("⏳ ClaudeCodeManager: Starting real-time message observation...")

      await observeMessagesRealTime(chatViewModel: chatViewModel)
    }

    // Wait for completion
    await currentTask?.value

    // Return final result
    guard let result = lastResult else {
      throw ClaudeCodeError.noResult
    }

    return result
  }

  // MARK: - Real-Time Observation

  /// Observe ChatViewModel messages in real-time using high-frequency polling
  /// This captures both new messages AND content updates to existing messages
  private func observeMessagesRealTime(chatViewModel: ChatViewModel) async {
    var lastProcessedCount = 0
    var lastMessageContentHashes: [UUID: Int] = [:]  // Track content changes
    var pollAttempts = 0
    let maxPollAttempts = 2400 // 2 minutes with 50ms intervals

    while !Task.isCancelled && pollAttempts < maxPollAttempts {
      let currentMessages = chatViewModel.messages
      let isLoading = chatViewModel.isLoading

      // Process new messages
      if currentMessages.count > lastProcessedCount {
        let newMessages = currentMessages[lastProcessedCount...]
        print("📨 ClaudeCodeManager: Processing \(newMessages.count) new message(s)")

        await MainActor.run {
          for message in newMessages {
            self.handleStreamingMessage(message)
            lastMessageContentHashes[message.id] = message.content.hashValue
          }
        }

        lastProcessedCount = currentMessages.count
      }

      // Check for content updates in existing messages (streaming text)
      // This catches the incremental updates that don't change the count
      for message in currentMessages {
        let currentHash = message.content.hashValue
        let previousHash = lastMessageContentHashes[message.id]

        if previousHash != currentHash {
          print("📨 ClaudeCodeManager: Content updated for message \(message.id)")
          await MainActor.run {
            self.handleStreamingMessage(message)
            lastMessageContentHashes[message.id] = currentHash
          }
        }
      }

      // Check if processing is complete
      if !isLoading {
        print("✅ ClaudeCodeManager: Processing complete after \(pollAttempts) polls")
        print("📊 ClaudeCodeManager: Final message count: \(currentMessages.count)")
        await MainActor.run {
          self.state = .completed
          self.lastResult = self.generateResultSummary()
        }
        break
      }

      // Poll every 50ms for very responsive streaming
      try? await Task.sleep(for: .milliseconds(50))
      pollAttempts += 1

      // Log every 100 attempts (every 5 seconds)
      if pollAttempts % 100 == 0 {
        print("⏳ ClaudeCodeManager: Still streaming... (\(pollAttempts) polls, isLoading: \(isLoading), messages: \(currentMessages.count))")
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

  // MARK: - Progress Tracking

  /// Handle streaming messages from ChatViewModel
  private func handleStreamingMessage(_ message: ChatMessage) {
    print("📨 Processing message type: \(message.messageType), role: \(message.role)")

    switch message.messageType {
    case .thinking:
      // Claude's internal reasoning
      if !message.content.isEmpty {
        addProgress(.thinking, content: "💭 Thinking: \(message.content)")
      }

    case .toolUse:
      // Tool invocation (Read, Edit, Bash, etc.)
      let toolName = message.toolName ?? "Unknown Tool"
      // Extract parameters from content if available
      let params = extractToolParameters(from: message.content, toolName: toolName)
      addProgress(
        .toolCall(name: toolName, parameters: params),
        content: "🔧 Using tool: \(toolName)\(params.isEmpty ? "" : "\n   \(params)")"
      )

    case .toolResult:
      // Tool execution result
      if !message.content.isEmpty {
        addProgress(.result, content: "✅ Result: \(message.content)")
      }

    case .toolError:
      // Tool execution error
      if !message.content.isEmpty {
        addProgress(.error, content: "❌ Error: \(message.content)")
      }

    case .text:
      // Regular text response from Claude
      if !message.content.isEmpty && message.role == .assistant {
        addProgress(.result, content: message.content)
      }

    case .webSearch:
      // Web search results
      if !message.content.isEmpty {
        addProgress(.result, content: "🔍 Web search: \(message.content)")
      }

    case .toolDenied:
      // User denied tool permission
      if !message.content.isEmpty {
        addProgress(.error, content: "🚫 Tool denied: \(message.content)")
      }

    case .codeExecution:
      // Code execution results
      if !message.content.isEmpty {
        addProgress(.result, content: "💻 Code execution: \(message.content)")
      }
    }
  }

  /// Extract tool parameters from content string for display
  private func extractToolParameters(from content: String, toolName: String) -> String {
    // The content field contains the tool parameters
    // For now, show a truncated version to avoid clutter
    let maxLength = 100
    let truncated = content.prefix(maxLength)

    if content.count > maxLength {
      return String(truncated) + "..."
    } else if !content.isEmpty {
      return content
    }

    return ""
  }

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
