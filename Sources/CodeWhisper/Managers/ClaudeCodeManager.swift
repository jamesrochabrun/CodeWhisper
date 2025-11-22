//
//  ClaudeCodeManager.swift
//  CodeWhisper
//
//  Manages Claude Code integration for voice-triggered coding tasks
//  Uses protocol-based architecture for dependency inversion
//

import Foundation
import Observation

/// Represents the current state of Claude Code execution
enum ClaudeCodeState: Equatable {
  case idle
  case processing
  case completed
  case error(String)
}

/// Detailed progress information from Claude Code streaming
public struct ClaudeCodeProgress: Identifiable, Equatable {
  public let id = UUID()
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

  public static func == (lhs: ClaudeCodeProgress, rhs: ClaudeCodeProgress) -> Bool {
    lhs.id == rhs.id
  }
}

@Observable
@MainActor
public final class ClaudeCodeManager {
  // Current state
  private(set) var state: ClaudeCodeState = .idle

  // Streaming progress updates
  private(set) var progressUpdates: [ClaudeCodeProgress] = []

  // Final result for AI to summarize
  private(set) var lastResult: String?

  // Protocol-based executor (replaces ChatViewModel)
  private var executor: ClaudeCodeExecutor?

  // Stream cancellation
  private var currentTask: Task<Void, Never>?

  // MARK: - Initialization

  /// Initialize with a ClaudeCodeExecutor implementation
  public func initialize(executor: ClaudeCodeExecutor) {
    self.executor = executor
    print("ClaudeCodeManager: Initialized with executor")
  }

  // MARK: - Execution

  /// Execute a Claude Code task with streaming progress
  public func executeTask(_ task: String, context: TaskContext? = nil) async throws -> String {
    guard let executor = executor else {
      print("❌ ClaudeCodeManager: Not initialized")
      throw ClaudeCodeError.notInitialized
    }

    print("🚀 ClaudeCodeManager: Executing task: \(task)")
    print("📊 ClaudeCodeManager: Executor isExecuting: \(executor.isExecuting)")
    print("📊 ClaudeCodeManager: Message count: \(executor.messages.count)")

    // Reset state
    state = .processing
    progressUpdates = []
    lastResult = nil

    // Cancel any existing task
    currentTask?.cancel()

    print("📤 ClaudeCodeManager: Sending task to executor...")

    // Start observation task in background - it will monitor progress
    currentTask = Task {
      print("⏳ ClaudeCodeManager: Starting real-time message observation...")
      await observeMessagesRealTime(executor: executor)
    }

    // Execute task and wait for the result directly
    // This is the source of truth - we await the executor's completion
    do {
      let result = try await executor.executeTask(task, context: context)
      print("✅ ClaudeCodeManager: Task completed with result content length: \(result.content.count)")

      // Cancel observation since execution is complete
      currentTask?.cancel()

      // Set state and result
      self.state = .completed
      self.lastResult = result.content

      // Return the result content directly from the executor
      return result.content
    } catch {
      print("❌ ClaudeCodeManager: Task failed with error: \(error)")

      // Cancel observation
      currentTask?.cancel()

      self.state = .error(error.localizedDescription)
      self.lastResult = "Error: \(error.localizedDescription)"
      throw error
    }
  }

  // MARK: - Real-Time Observation

  /// Observe executor messages in real-time using high-frequency polling
  /// This captures both new messages AND content updates to existing messages
  /// Note: This runs in parallel with execution and will be cancelled when execution completes
  private func observeMessagesRealTime(executor: ClaudeCodeExecutor) async {
    var lastProcessedCount = 0
    var lastMessageContentHashes: [UUID: Int] = [:]  // Track content changes
    var pollAttempts = 0
    let maxPollAttempts = 2400 // 2 minutes with 50ms intervals
    var hasStarted = false  // Track if execution has started

    while !Task.isCancelled && pollAttempts < maxPollAttempts {
      let currentMessages = executor.messages
      let isExecuting = executor.isExecuting

      // Track if execution has started
      if isExecuting {
        hasStarted = true
      }

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

      // Only exit when execution has started AND completed
      // This prevents exiting before execution begins
      if hasStarted && !isExecuting {
        print("✅ ClaudeCodeManager: Observation complete after \(pollAttempts) polls")
        print("📊 ClaudeCodeManager: Final message count: \(currentMessages.count)")
        break
      }

      // Poll every 50ms for very responsive streaming
      try? await Task.sleep(for: .milliseconds(50))
      pollAttempts += 1

      // Log every 100 attempts (every 5 seconds)
      if pollAttempts % 100 == 0 {
        print("⏳ ClaudeCodeManager: Still streaming... (\(pollAttempts) polls, isExecuting: \(isExecuting), hasStarted: \(hasStarted), messages: \(currentMessages.count))")
      }
    }

    // Log if cancelled or timed out
    if Task.isCancelled {
      print("🛑 ClaudeCodeManager: Observation cancelled after \(pollAttempts) polls")
    } else if pollAttempts >= maxPollAttempts {
      print("⏰ ClaudeCodeManager: Observation timeout after \(pollAttempts) polls")
    }
  }

  // MARK: - Progress Tracking

  /// Handle streaming messages from executor
  private func handleStreamingMessage(_ message: CodeExecutionMessage) {
    print("📨 Processing message type: \(message.type), role: \(message.role)")

    switch message.type {
    case .thinking:
      // Skip thinking messages - too verbose
      break

    case .toolUse(let toolName):
      // Tool invocation (Read, Edit, Bash, etc.)
      let actionText = formatToolAction(toolName: toolName, parameters: message.content)
      addProgress(
        .toolCall(name: toolName, parameters: ""),
        content: actionText
      )

    case .toolResult:
      // Tool execution result (truncated)
      if !message.content.isEmpty {
        let truncated = truncateContent(message.content, maxChars: 80)
        addProgress(.result, content: "Result: \(truncated)")
      }

    case .toolError:
      // Tool execution error (truncated)
      if !message.content.isEmpty {
        let truncated = truncateContent(message.content, maxChars: 80)
        addProgress(.error, content: "Error: \(truncated)")
      }

    case .text:
      // Regular text response from Claude (truncated)
      if !message.content.isEmpty && message.role == .assistant {
        let truncated = truncateContent(message.content, maxChars: 80)
        addProgress(.result, content: truncated)
      }

    case .webSearch:
      // Web search
      if !message.content.isEmpty {
        addProgress(.result, content: "Searching web")
      }

    case .toolDenied:
      // User denied tool permission
      if !message.content.isEmpty {
        addProgress(.error, content: "Tool access denied")
      }

    case .codeExecution:
      // Code execution
      if !message.content.isEmpty {
        let truncated = truncateContent(message.content, maxChars: 80)
        addProgress(.result, content: "Executed: \(truncated)")
      }
    }
  }

  /// Convert tool name to action verb and extract target
  private func formatToolAction(toolName: String, parameters: String) -> String {
    // Convert tool name to action verb
    let action: String
    switch toolName {
    case "Read": action = "Reading"
    case "Edit": action = "Editing"
    case "Write": action = "Writing"
    case "Bash": action = "Running"
    case "Grep": action = "Searching"
    case "Glob": action = "Finding"
    case "WebFetch": action = "Fetching"
    case "WebSearch": action = "Searching"
    case "Task": action = "Starting task"
    default: action = toolName
    }

    // Extract target from parameters
    let target = extractToolTarget(from: parameters, toolName: toolName)

    if target.isEmpty {
      return action
    } else {
      return "\(action) \(target)"
    }
  }

  /// Extract the main target from tool parameters (file path, command, etc.)
  private func extractToolTarget(from parameters: String, toolName: String) -> String {
    // Try to parse JSON parameters
    guard let data = parameters.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return ""
    }

    // Extract relevant field based on tool type
    let targetField: String
    switch toolName {
    case "Read", "Edit", "Write":
      targetField = "file_path"
    case "Bash":
      targetField = "command"
    case "Grep":
      targetField = "pattern"
    case "Glob":
      targetField = "pattern"
    case "WebFetch", "WebSearch":
      targetField = "url"
    default:
      return ""
    }

    guard let value = json[targetField] as? String else {
      return ""
    }

    // For file paths, show just the filename
    if targetField == "file_path" {
      let filename = (value as NSString).lastPathComponent
      return filename
    }

    // For commands/patterns, truncate if needed
    if value.count > 40 {
      return String(value.prefix(40)) + "..."
    }

    return value
  }

  /// Truncate content to specified character limit
  private func truncateContent(_ content: String, maxChars: Int) -> String {
    if content.count > maxChars {
      return String(content.prefix(maxChars)) + "..."
    }
    return content
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

  private func generateResultSummary(from messages: [CodeExecutionMessage]) -> String {
    // Get messages count
    let messageCount = messages.count
    let hasMessages = messageCount > 0

    // Generate simple summary
    var summary = "Claude Code execution completed.\n\n"

    if hasMessages {
      summary += "Processed \(messageCount) message(s)\n"

      // Try to get the last assistant message text
      if let lastMessage = messages.last(where: { $0.role == .assistant }) {
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

  public func cancel() {
    currentTask?.cancel()
    currentTask = nil
    executor?.cancelTask()
    state = .idle
  }
}

// MARK: - Errors

enum ClaudeCodeError: LocalizedError {
  case notInitialized
  case noResult

  public var errorDescription: String? {
    switch self {
    case .notInitialized:
      return "ClaudeCodeManager not initialized"
    case .noResult:
      return "No result from Claude Code execution"
    }
  }
}
