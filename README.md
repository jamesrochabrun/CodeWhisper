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

## Required Permissions

### Info.plist Keys

Add the following keys to your app's `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>CodeWhisper needs microphone access for voice conversations with AI</string>

<key>NSScreenCaptureUsageDescription</key>
<string>CodeWhisper needs screen capture access to share visual context with AI</string>
```

### Entitlements

#### macOS
For macOS apps, you need to configure the following entitlements:

1. **Microphone Access**: Required for voice conversations
2. **Screen Capture**: Required for screenshot functionality
3. **App Sandbox**: Disable App Sandbox or configure appropriate exceptions for file system access

Example `YourApp.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.microphone</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

**Note**: For App Store distribution, you'll need to enable App Sandbox and request specific entitlements. For development and non-App Store distribution, you can disable App Sandbox as shown above.

#### iOS/visionOS
For iOS and visionOS apps:
- Microphone permission is requested automatically when needed
- No additional entitlements required beyond Info.plist keys

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
