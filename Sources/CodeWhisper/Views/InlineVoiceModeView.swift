//
//  InlineVoiceModeView.swift
//  CodeWhisper
//
//  Created by Claude on 11/26/25.
//

import SwiftUI

/// A compact inline voice mode view designed to be embedded in chat UIs.
/// Provides the same functionality as `VoiceModeView` but in a horizontal bar format.
public struct InlineVoiceModeView: View {

    public enum PresentationMode {
        case standalone
        case presented
    }

    @Environment(OpenAIServiceManager.self) private var serviceManager
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var conversationManager = ConversationManager()
    @State private var isInitializing = true
    @State private var showScreenshotPicker = false
    @State private var showingSettings = false

    private let height: CGFloat
    private let presentationMode: PresentationMode
    private let executor: ClaudeCodeExecutor?

    public init(
        height: CGFloat = 42,
        presentationMode: PresentationMode = .standalone,
        executor: ClaudeCodeExecutor? = nil
    ) {
        self.height = height
        self.presentationMode = presentationMode
        self.executor = executor
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Left buttons
            leftButtons

            // Center: Audio visualizer
            audioVisualizer

            // Right buttons
            rightButtons
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background {
            glassBackground
        }
        .overlay {
            // Error indicator (subtle for inline view)
            if conversationManager.errorMessage != nil {
                errorIndicator
            }
        }
        .animation(.easeInOut(duration: 0.2), value: conversationManager.isExecutingTool)
        .animation(.easeInOut(duration: 0.2), value: conversationManager.errorMessage == nil)
        .task {
            await startConversation()
        }
        .sheet(isPresented: $showScreenshotPicker) {
            ScreenshotPickerView { base64DataURL in
                Task {
                    await conversationManager.sendImage(base64DataURL)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - View Components

    private var leftButtons: some View {
        HStack(spacing: 6) {
            screenshotButton
            muteButton
        }
    }

    private var rightButtons: some View {
        HStack(spacing: 6) {
            if conversationManager.isExecutingTool {
                stopProcessButton
            }
            settingsButton
            if presentationMode == .presented {
                closeButton
            }
        }
    }

    private var screenshotButton: some View {
        Button {
            showScreenshotPicker = true
        } label: {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .disabled(!conversationManager.isConnected)
        .opacity(conversationManager.isConnected ? 1.0 : 0.5)
        .help("Capture and send screenshot")
    }

    private var muteButton: some View {
        Button {
            conversationManager.toggleMicrophoneMute()
        } label: {
            Image(systemName: conversationManager.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 18))
                .foregroundStyle(conversationManager.isMicrophoneMuted ? .pink : .white.opacity(0.7))
        }
        .disabled(!conversationManager.isConnected)
        .buttonStyle(.plain)
        .opacity(conversationManager.isConnected ? 1.0 : 0.5)
        .help(conversationManager.isMicrophoneMuted ? "Unmute microphone (⌘M)" : "Mute microphone (⌘M)")
        .keyboardShortcut("m", modifiers: .command)
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gear")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    private var closeButton: some View {
        Button {
            conversationManager.stopConversation()
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .help("Close (⌘W)")
        .keyboardShortcut("w", modifiers: .command)
    }

    private var stopProcessButton: some View {
        Button {
            conversationManager.cancelToolExecution()
        } label: {
            Text("Stop")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.6))
                )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private var audioVisualizer: some View {
        InlineAudioVisualizerView(conversationManager: conversationManager)
            .frame(maxWidth: .infinity)
            .frame(height: height - 12) // Leave some padding
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var glassBackground: some View {
        #if os(visionOS)
        Color.clear.glassBackgroundEffect()
        #else
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
        #endif
    }

    private var errorIndicator: some View {
        HStack {
            Spacer()
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.5)
                )
            Spacer()
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: - Methods

    private func startConversation() async {
        guard let service = serviceManager.service else {
            isInitializing = false
            return
        }

        isInitializing = true
        conversationManager.setSettingsManager(settingsManager)

        // Set the ClaudeCodeExecutor if provided
        if let executor = executor {
            conversationManager.setClaudeCodeExecutor(executor)
        }

        let configuration = serviceManager.createSessionConfiguration()
        await conversationManager.startConversation(service: service, configuration: configuration)
        isInitializing = false
    }
}

#Preview {
    VStack {
        Spacer()
        InlineVoiceModeView()
            .padding()
        Spacer()
    }
    .background(Color.black)
    .environment(OpenAIServiceManager())
    .environment(SettingsManager())
}
