# CodeWhisper

A real-time voice-enabled AI coding assistant for macOS, iOS, and visionOS that integrates OpenAI's Realtime API with Claude Code for powerful coding assistance through voice conversations.

## Features

- **Voice-to-Voice AI Conversations**: Real-time audio conversations with GPT-4 using OpenAI's Realtime API
- **Claude Code Integration**: Execute coding tasks (file operations, refactoring, debugging) through voice commands
- **Screenshot Capture**: Share visual context with AI using macOS ScreenCaptureKit
- **Audio Visualization**: Real-time audio visualization during conversations (Metal and SwiftUI Canvas)
- **MCP Server Support**: Extend capabilities with Model Context Protocol servers
- **Multi-Platform**: Works on macOS, iOS, and visionOS

## Installation

### Swift Package Manager

Add CodeWhisper to your project using Swift Package Manager:

#### In Xcode:
1. File > Add Package Dependencies...
2. Enter the repository URL: `https://github.com/YOUR_USERNAME/CodeWhisper`
3. Select the version you want to use
4. Add the `CodeWhisper` product to your target

#### In Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USERNAME/CodeWhisper", from: "1.0.0")
]
```

Then add it to your target dependencies:
```swift
.target(
    name: "YourTarget",
    dependencies: ["CodeWhisper"]
)
```

## Usage

### Basic Setup

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
            ContentView()
                .environment(settingsManager)
                .environment(mcpServerManager)
                .environment(serviceManager)
                .onChange(of: settingsManager.apiKey) { _, newValue in
                    serviceManager.updateService(apiKey: newValue)
                }
                .onAppear {
                    serviceManager.updateService(apiKey: settingsManager.apiKey)
                    serviceManager.setMCPServerManager(mcpServerManager)
                }
        }
    }
}
```

### Using the Voice Mode

```swift
import SwiftUI
import CodeWhisper

struct MyView: View {
    var body: some View {
        VoiceModeView()
    }
}
```

## Required Permissions & Entitlements

CodeWhisper requires specific permissions and entitlements to enable its features. This section covers all the configuration needed for consumer apps.

### Info.plist Keys

Add the following keys to your app's `Info.plist`:

```xml
<!-- Required: Voice conversation functionality -->
<key>NSMicrophoneUsageDescription</key>
<string>CodeWhisper needs access to your microphone to enable real-time voice conversations with AI.</string>

<!-- Required: Screenshot capture functionality -->
<key>NSScreenCaptureUsageDescription</key>
<string>CodeWhisper needs screen recording permission to capture screenshots that you can share with the AI assistant for visual context.</string>
```

### Entitlements (macOS)

Create a `YourApp.entitlements` file with the following configuration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Disable App Sandbox for Claude Code file system access -->
    <key>com.apple.security.app-sandbox</key>
    <false/>

    <!-- Required: Microphone access for voice conversations -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- Required: Screen capture for screenshot functionality -->
    <key>com.apple.security.device.screen-capture</key>
    <true/>

    <!-- Required: Keychain access for secure API key storage -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)YOUR_BUNDLE_ID</string>
    </array>
</dict>
</plist>
```

> **Important**: Replace `YOUR_BUNDLE_ID` with your actual app bundle identifier (e.g., `com.yourcompany.yourapp`).

### Entitlements Breakdown

| Entitlement | Purpose | Required For |
|-------------|---------|--------------|
| `com.apple.security.app-sandbox` = `false` | Disables sandboxing | Claude Code file system operations |
| `com.apple.security.device.audio-input` | Microphone access | Voice conversations with OpenAI Realtime API |
| `com.apple.security.device.screen-capture` | Screen recording | Screenshot capture via ScreenCaptureKit |
| `keychain-access-groups` | Keychain access | Secure storage of API keys |

### Runtime Permissions

The following permissions will be requested at runtime (macOS will show system dialogs):

1. **Microphone Permission**: Requested when starting a voice conversation
   - System Settings → Privacy & Security → Microphone

2. **Screen Recording Permission**: Requested when capturing screenshots
   - System Settings → Privacy & Security → Screen Recording

### iOS/visionOS

For iOS and visionOS apps:
- Microphone permission is requested automatically when needed
- Screen recording is not available on iOS (screenshots use different APIs)
- No additional entitlements file required beyond Info.plist keys

### App Store Distribution

For **App Store distribution**, you cannot disable App Sandbox. You'll need to:

1. Enable App Sandbox: `com.apple.security.app-sandbox` = `true`
2. Add specific file access entitlements:
   ```xml
   <key>com.apple.security.files.user-selected.read-write</key>
   <true/>
   <key>com.apple.security.files.downloads.read-write</key>
   <true/>
   ```
3. Note: Full Claude Code functionality may be limited due to sandbox restrictions

For **non-App Store distribution** (Developer ID, direct distribution), disabling the sandbox as shown above is recommended for full functionality.

## Configuration

### API Keys

CodeWhisper requires an OpenAI API key. You can configure it in the Settings view:

```swift
import CodeWhisper

// Access settings
@Environment(SettingsManager.self) private var settingsManager

// Set API key
settingsManager.apiKey = "your-openai-api-key"
```

### Working Directory

For Claude Code integration, configure the working directory where code operations should be performed:

```swift
settingsManager.workingDirectory = "/path/to/your/project"
```

### MCP Servers

Configure Model Context Protocol servers to extend AI capabilities:

```swift
@Environment(MCPServerManager.self) private var mcpServerManager

// Add an MCP server
mcpServerManager.addServer(name: "MyServer", command: "node", arguments: ["server.js"])
```

## Components

### Managers
- **ConversationManager**: Manages OpenAI Realtime sessions and audio streaming
- **ClaudeCodeManager**: Integrates Claude Code SDK for coding task execution
- **OpenAIServiceManager**: Manages OpenAI service configuration
- **SettingsManager**: Handles API keys, working directory, and permissions
- **MCPServerManager**: Manages MCP server configurations

### Views
- **ContentView**: Landing page with "Start Voice Mode" button
- **VoiceModeView**: Main voice conversation interface
- **SettingsView**: Settings configuration UI
- **MCPSettingsView**: MCP server configuration UI
- **ConversationTranscriptView**: Shows conversation history

### Utilities
- **AudioAnalyzer**: FFT-based audio analysis for visualizations
- **ScreenshotCapture**: macOS screenshot capture using ScreenCaptureKit
- **WindowMatcher**: Matches windows by app name or title for targeted screenshots

### Visualizers
- **MetalAudioVisualizerView**: Metal-based GPU audio visualization
- **SwiftUIAudioVisualizerView**: SwiftUI Canvas-based audio visualization

## Platform Support

- **macOS**: 15.6+
- **iOS**: 17.0+
- **visionOS**: 1.0+

## Dependencies

CodeWhisper depends on:
- [SwiftOpenAI](https://github.com/jamesrochabrun/SwiftOpenAI) - OpenAI API client
- [ClaudeCodeUI](https://github.com/jamesrochabrun/ClaudeCodeUI) - Claude Code SDK integration

## Example App

This repository includes an example app that demonstrates all features of the CodeWhisper package. To run it:

1. Clone the repository
2. Open `Example/CodeWhisperDemo.xcodeproj` in Xcode
3. Add your OpenAI API key in the Settings view
4. Build and run the example app

The example app is located in the `Example/` directory and is **not included** when you install the package via SPM - it's only for demonstration and development purposes.

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]

## Support

[Add support information here]
