import Foundation

// MARK: - Protocol Definitions

/// Protocol defining the interface for executing Claude Code tasks
/// This abstraction allows CodeWhisper to be independent of specific Claude Code implementations
@MainActor
public protocol ClaudeCodeExecutor: AnyObject {
  /// Current execution state
  var isExecuting: Bool { get }
  
  /// Array of messages from the current conversation
  var messages: [CodeExecutionMessage] { get }
  
  /// Working directory for code execution
  var workingDirectory: String? { get set }
  
  /// Initialize the executor with configuration
  /// - Parameter configuration: Configuration settings for the executor
  func initialize(configuration: ClaudeCodeExecutorConfiguration) async throws
  
  /// Execute a coding task
  /// - Parameters:
  ///   - task: The task description or prompt
  ///   - context: Optional context for the task (e.g., screenshots, additional info)
  /// - Returns: Result of the execution
  func executeTask(_ task: String, context: TaskContext?) async throws -> ClaudeCodeResult
  
  /// Cancel the currently executing task
  func cancelTask()
  
  /// Reset the conversation/session
  func reset()
}

// MARK: - Configuration

/// Configuration for Claude Code executor
public struct ClaudeCodeExecutorConfiguration {
  /// Working directory for code operations
  public var workingDirectory: String?
  
  /// Enable debug logging
  public var enableDebugLogging: Bool
  
  /// Additional paths to add to PATH environment variable
  public var additionalPaths: [String]
  
  /// Permission mode for operations
  public var permissionMode: ExecutorPermissionMode
  
  /// System prompt prefix (optional)
  public var systemPromptPrefix: String?
  
  /// MCP server configurations
  public var mcpServers: [MCPServerConfiguration]
  
  public init(
    workingDirectory: String? = nil,
    enableDebugLogging: Bool = false,
    additionalPaths: [String] = [],
    permissionMode: ExecutorPermissionMode = .default,
    systemPromptPrefix: String? = nil,
    mcpServers: [MCPServerConfiguration] = []
  ) {
    self.workingDirectory = workingDirectory
    self.enableDebugLogging = enableDebugLogging
    self.additionalPaths = additionalPaths
    self.permissionMode = permissionMode
    self.systemPromptPrefix = systemPromptPrefix
    self.mcpServers = mcpServers
  }
}

/// Permission mode for executor operations
public enum ExecutorPermissionMode {
  case `default`
  case bypassPermissions
}

/// MCP Server configuration
public struct MCPServerConfiguration: Codable, Identifiable, Equatable {
  public let id: UUID
  public var name: String
  public var command: String
  public var args: [String]
  public var env: [String: String]
  public var isEnabled: Bool
  
  public init(
    id: UUID = UUID(),
    name: String,
    command: String,
    args: [String] = [],
    env: [String: String] = [:],
    isEnabled: Bool = true
  ) {
    self.id = id
    self.name = name
    self.command = command
    self.args = args
    self.env = env
    self.isEnabled = isEnabled
  }
}

// MARK: - Task Context

/// Context information for task execution
public struct TaskContext {
  /// Screenshots or images to include
  public var images: [ImageData]
  
  /// Additional text context
  public var additionalInfo: String?
  
  public init(images: [ImageData] = [], additionalInfo: String? = nil) {
    self.images = images
    self.additionalInfo = additionalInfo
  }
}

/// Image data for task context
public struct ImageData {
  /// Image data (PNG, JPEG, etc.)
  public let data: Data
  
  /// Media type (e.g., "image/png")
  public let mediaType: String
  
  public init(data: Data, mediaType: String = "image/png") {
    self.data = data
    self.mediaType = mediaType
  }
}

// MARK: - Result Types

/// Result of a Claude Code task execution
public struct ClaudeCodeResult {
  /// Final text content/response
  public let content: String
  
  /// All messages from the execution
  public let messages: [CodeExecutionMessage]
  
  /// Token usage statistics (if available)
  public let tokenUsage: TokenUsage?
  
  /// Whether the task completed successfully
  public let success: Bool
  
  public init(
    content: String,
    messages: [CodeExecutionMessage],
    tokenUsage: TokenUsage? = nil,
    success: Bool = true
  ) {
    self.content = content
    self.messages = messages
    self.tokenUsage = tokenUsage
    self.success = success
  }
}

/// Message from code execution
public struct CodeExecutionMessage: Identifiable, Equatable {
  public let id: UUID
  public let type: MessageType
  public let role: MessageRole
  public let content: String
  public let timestamp: Date
  public let toolName: String?
  
  public init(
    id: UUID = UUID(),
    type: MessageType,
    role: MessageRole,
    content: String,
    timestamp: Date = Date(),
    toolName: String? = nil
  ) {
    self.id = id
    self.type = type
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.toolName = toolName
  }
  
  public static func == (lhs: CodeExecutionMessage, rhs: CodeExecutionMessage) -> Bool {
    lhs.id == rhs.id
  }
}

/// Type of execution message
public enum MessageType: Equatable {
  case thinking
  case toolUse(toolName: String)
  case toolResult
  case toolError
  case text
  case webSearch
  case toolDenied
  case codeExecution
}

/// Role of the message sender
public enum MessageRole: Equatable {
  case user
  case assistant
  case system
}

/// Token usage statistics
public struct TokenUsage {
  public let inputTokens: Int
  public let outputTokens: Int
  public let totalTokens: Int
  
  public init(inputTokens: Int, outputTokens: Int) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.totalTokens = inputTokens + outputTokens
  }
}
