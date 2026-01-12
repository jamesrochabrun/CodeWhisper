# CodeWhisper

A voice-enabled AI assistant framework for macOS, iOS, and visionOS. Supports multiple voice modes from simple speech-to-text to full bidirectional realtime conversations with OpenAI's APIs.

## Features

- **Multiple Voice Modes**: Choose between Speech-to-Text, Voice Chat, or Realtime conversations
- **Floating STT** (macOS): System-wide floating voice button with automatic text insertion
- **Drop-in Integration**: Add voice capabilities with a single `CodeWhisperButton`
- **Configurable**: Control which voice modes are available per-button
- **Prompt Enhancement**: AI-powered text improvement for transcriptions
- **Claude Code Integration**: Execute coding tasks through voice commands (Realtime mode)
- **MCP Server Support**: Extend capabilities with Model Context Protocol servers
- **Multi-Platform**: Works on macOS, iOS, and visionOS

## Voice Modes

CodeWhisper supports three voice modes, each suited for different use cases:

| Mode | Description | Use Case |
|------|-------------|----------|
| **Speech to Text** (`.stt`) | Tap to record, transcribes to text | Text input via voice, dictation |
| **Voice Chat** (`.sttWithTTS`) | Speak and hear responses | Conversational AI with voice I/O |
| **Realtime** (`.realtime`) | Full bidirectional conversation | Live coding assistance, complex interactions |

## Floating STT (macOS)

A floating voice-to-text button that works system-wide on macOS. Records speech, transcribes it, and automatically inserts text into any focused text field.

### Quick Start

```swift
import CodeWhisper

// Menu bar mode (default) - shows in menu bar
FloatingSTT.configure(apiKey: "sk-...")
FloatingSTT.show()

// Embedded mode - no menu bar, hover for settings
FloatingSTT.configure(apiKey: "sk-...", embedded: true)
FloatingSTT.show()

// Toggle visibility
FloatingSTT.toggle()

// Hide
FloatingSTT.hide()
```

### Display Modes

| Mode | Menu Bar | Settings Access | Use Case |
|------|----------|-----------------|----------|
| **Menu Bar** (default) | Yes | Via menu bar item | Standalone usage |
| **Embedded** | No | Hover to reveal gear | Host app integration |

### Configuration

```swift
var config = FloatingSTTConfiguration()
config.displayMode = .embedded
config.enhancementEnabled = true  // AI text enhancement
config.customEnhancementPrompt = "Fix grammar and punctuation"
config.rememberPosition = true

FloatingSTT.configure(apiKey: "sk-...", configuration: config)
```

### Event Handling

```swift
FloatingSTT.shared.onTextInserted = { text, result in
    print("Inserted: \(text)")
}

FloatingSTT.shared.onError = { error in
    print("Error: \(error)")
}
```

### Permissions

Floating STT requires:
- **Microphone**: For recording speech
- **Accessibility** (optional): For direct text insertion into other apps

Without Accessibility permission, text is copied to clipboard and Cmd+V is simulated.

```swift
// Check permission
if FloatingSTT.hasAccessibilityPermission {
    // Direct insertion available
}

// Request permission
FloatingSTT.requestAccessibilityPermission()

// Open System Settings
FloatingSTT.openAccessibilitySettings()
```

## Installation

### Swift Package Manager

Add CodeWhisper to your project:

#### In Xcode:
1. File > Add Package Dependencies...
2. Enter the repository URL: `https://github.com/jamesrochabrun/CodeWhisper`
3. Select the version you want to use

#### In Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/jamesrochabrun/CodeWhisper", from: "1.0.0")
]
```

## Quick Start

### 1. Add the Button

The simplest integration - just add `CodeWhisperButton` to your view:

```swift
import SwiftUI
import CodeWhisper

struct ChatView: View {
    var body: some View {
        HStack {
            TextField("Message...", text: $message)

            // Add voice input button
            CodeWhisperButton(chatInterface: nil)
        }
    }
}
```

### 2. Handle Transcriptions

To receive transcribed text, implement `VoiceModeChatInterface`:

```swift
import SwiftUI
import CodeWhisper

struct ChatView: View {
    @State private var message = ""
    @StateObject private var chatHandler = MyChatHandler()

    var body: some View {
        HStack {
            TextField("Message...", text: $message)

            CodeWhisperButton(
                chatInterface: chatHandler,
                onTranscription: { text in
                    // User's speech was transcribed
                    message = text
                }
            )
        }
    }
}

class MyChatHandler: VoiceModeChatInterface {
    // Publisher for assistant responses (used in Voice Chat mode)
    var assistantMessageCompletedPublisher: AnyPublisher<VoiceModeMessage, Never> {
        // Return your publisher here
    }

    func sendVoiceMessage(_ text: String) {
        // Handle the transcribed message
    }
}
```

### 3. Configure Available Modes

Control which voice modes users can select:

```swift
// All modes (default)
CodeWhisperButton(chatInterface: handler)

// Speech-to-text only - no mode picker shown
CodeWhisperButton(
    chatInterface: handler,
    configuration: .sttOnly
)

// Voice chat only
CodeWhisperButton(
    chatInterface: handler,
    configuration: .voiceChatOnly
)

// Exclude realtime mode
CodeWhisperButton(
    chatInterface: handler,
    configuration: .noRealtime
)

// Custom combination
CodeWhisperButton(
    chatInterface: handler,
    configuration: CodeWhisperConfiguration(
        availableVoiceModes: [.stt, .sttWithTTS]
    )
)
```

### 4. Realtime Mode with Claude Code

For realtime voice with coding capabilities, provide a `ClaudeCodeExecutor`:

```swift
CodeWhisperButton(
    chatInterface: handler,
    executor: claudeCodeExecutor,
    configuration: .realtimeOnly,
    isRealtimeSessionActive: $isActive
)
```

## Configuration Presets

| Preset | Modes Included | Picker Shown |
|--------|----------------|--------------|
| `.all` | STT, Voice Chat, Realtime | Yes |
| `.sttOnly` | STT | No |
| `.voiceChatOnly` | Voice Chat | No |
| `.realtimeOnly` | Realtime | No |
| `.noRealtime` | STT, Voice Chat | Yes |

When only one mode is configured, the voice mode picker is hidden in settings.

## Button Behavior

`CodeWhisperButton` provides two interactions:

- **Tap**: Starts the currently selected voice mode
- **Long Press**: Opens the settings sheet

The button automatically handles:
- API key validation (prompts for settings if missing)
- Mode switching based on user preference
- Inline UI for STT/Voice Chat modes
- Sheet presentation for Realtime mode

## App Setup

### Environment Setup

For full functionality, set up the required environment objects:

```swift
import SwiftUI
import CodeWhisper

@main
struct YourApp: App {
    @State private var settingsManager = SettingsManager()
    @State private var mcpServerManager = MCPServerManager()
    @State private var serviceManager = OpenAIServiceManager()

    var body: some Scene {
        WindowGroup {
            YourContentView()
                .environment(settingsManager)
                .environment(mcpServerManager)
                .environment(serviceManager)
                .onAppear {
                    serviceManager.updateService(apiKey: settingsManager.apiKey)
                }
                .onChange(of: settingsManager.apiKey) { _, newValue in
                    serviceManager.updateService(apiKey: newValue)
                }
        }
    }
}
```

### API Key Configuration

CodeWhisper requires an OpenAI API key. Users can configure it via:

1. **Settings Sheet** (long-press on `CodeWhisperButton`)
2. **Environment Variable**: Set `OPENAI_API_KEY`
3. **Programmatically**:
```swift
settingsManager.apiKey = "sk-..."
```

## Required Permissions & Entitlements

### Info.plist Keys

```xml
<!-- Required: Voice functionality -->
<key>NSMicrophoneUsageDescription</key>
<string>Enable voice conversations with AI.</string>

<!-- Optional: Screenshot capture (Realtime mode) -->
<key>NSScreenCaptureUsageDescription</key>
<string>Share screenshots with the AI assistant.</string>
```

### macOS Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Disable sandbox for Claude Code file access -->
    <key>com.apple.security.app-sandbox</key>
    <false/>

    <!-- Microphone access -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- Screen capture (optional) -->
    <key>com.apple.security.device.screen-capture</key>
    <true/>

    <!-- Keychain for API key storage -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)YOUR_BUNDLE_ID</string>
    </array>
</dict>
</plist>
```

### App Store Distribution

For App Store apps, enable sandbox with file access:
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

Note: Full Claude Code functionality requires sandbox disabled (Developer ID distribution).

## Components

### Entry Points
- **CodeWhisperButton**: Primary integration point - compact button with tap/long-press actions
- **CodeWhisperSettingsSheet**: Settings UI shown on long-press

### Voice Mode Views
- **InlineVoiceModeView**: Inline STT/Voice Chat interface
- **VoiceModeView**: Full-screen Realtime conversation interface
- **STTModeView**: Speech-to-text recording interface

### Managers
- **SettingsManager**: API keys, voice mode selection, TTS configuration
- **OpenAIServiceManager**: OpenAI API service management
- **MCPServerManager**: MCP server configuration
- **STTManager**: Speech-to-text recording and transcription
- **TTSSpeaker**: Text-to-speech playback

### Configuration
- **CodeWhisperConfiguration**: Controls available voice modes per-button
- **TTSConfiguration**: TTS provider and voice settings
- **VoiceMode**: Enum defining available modes (`.stt`, `.sttWithTTS`, `.realtime`)

### Floating STT (macOS only)
- **FloatingSTT**: Public API enum for floating button control
- **FloatingSTTConfiguration**: Position, enhancement, display mode settings
- **FloatingSTTManager**: Core orchestrator with callbacks and state

## Platform Support

| Platform | Minimum Version | Notes |
|----------|-----------------|-------|
| macOS | 15.0+ | Full feature support including Floating STT |
| iOS | 17.0+ | Voice modes only (no Floating STT) |
| visionOS | 1.0+ | Voice modes only (no Floating STT) |

## Dependencies

- [SwiftOpenAI](https://github.com/jamesrochabrun/SwiftOpenAI) - OpenAI API client
- [ClaudeCodeUI](https://github.com/jamesrochabrun/ClaudeCodeUI) - Claude Code SDK integration

## License

MIT License

## Contributing

Contributions welcome! Please open an issue or submit a pull request.
