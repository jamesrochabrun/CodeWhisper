//
//  ScreenshotCapture.swift
//  CodeWhisper
//
//  Screenshot capture utility for macOS
//

import Foundation
import AppKit
import ScreenCaptureKit
import Observation

@Observable
@MainActor
public class ScreenshotCapture {
  public var capturedImage: NSImage?
  public var isCapturing = false
  public var errorMessage: String?

  /// Capture a screenshot using the system screenshot picker
  public func captureScreenshot() async {
    isCapturing = true
    errorMessage = nil

    do {
      // Get available content for screen capture
      // This will automatically trigger the system permission dialog on first use
      let content = try await SCShareableContent.current

      guard let display = content.displays.first else {
        errorMessage = "No display found"
        isCapturing = false
        return
      }

      // Create filter for the entire display
      let filter = SCContentFilter(display: display, excludingWindows: [])

      // Configure screenshot
      let configuration = SCStreamConfiguration()
      configuration.width = Int(display.width)
      configuration.height = Int(display.height)
      configuration.scalesToFit = true
      configuration.showsCursor = true

      // Capture single frame
      let image = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: configuration
      )

      // Convert CGImage to NSImage
      capturedImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
      isCapturing = false

    } catch {
      errorMessage = "Failed to capture screenshot: \(error.localizedDescription)\n\nIf you denied screen recording permission, you'll need to grant it in System Settings."
      isCapturing = false
    }
  }

  /// Capture a specific window
  public func captureWindow(_ window: SCWindow) async {
    isCapturing = true
    errorMessage = nil

    do {
      // Create filter for specific window
      let filter = SCContentFilter(desktopIndependentWindow: window)

      // Configure screenshot
      let configuration = SCStreamConfiguration()
      configuration.width = Int(window.frame.width)
      configuration.height = Int(window.frame.height)
      configuration.scalesToFit = true
      configuration.showsCursor = false

      // Capture single frame
      let image = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: configuration
      )

      // Convert CGImage to NSImage
      capturedImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
      isCapturing = false

    } catch {
      errorMessage = "Failed to capture window: \(error.localizedDescription)\n\nIf you denied screen recording permission, you'll need to grant it in System Settings."
      isCapturing = false
    }
  }

  /// Convert NSImage to base64 data URL for OpenAI API
  public func convertToBase64DataURL(_ image: NSImage, format: ImageFormat = .png, quality: CGFloat = 0.8) -> String? {
    guard let tiffData = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData) else {
      return nil
    }

    let imageData: Data?
    let mimeType: String

    switch format {
    case .png:
      imageData = bitmapImage.representation(using: .png, properties: [:])
      mimeType = "image/png"
    case .jpeg:
      imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: quality])
      mimeType = "image/jpeg"
    }

    guard let data = imageData else {
      return nil
    }

    let base64String = data.base64EncodedString()
    return "data:\(mimeType);base64,\(base64String)"
  }

  /// Clear captured image
  public func clearImage() {
    capturedImage = nil
    errorMessage = nil
  }

  public enum ImageFormat {
    case png
    case jpeg
  }
}

// MARK: - Screenshot Picker View

import SwiftUI

public struct ScreenshotPickerView: View {
  @State private var capture = ScreenshotCapture()
  @Environment(\.dismiss) private var dismiss
  @State private var selectedWindow: SCWindow?
  @State private var availableWindows: [SCWindow] = []

  let onImageCaptured: (String) -> Void

  public var body: some View {
    VStack(spacing: 20) {
      Text("Capture Screenshot")
        .font(.title2)
        .fontWeight(.semibold)

      if let errorMessage = capture.errorMessage {
        VStack(spacing: 12) {
          Text(errorMessage)
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

          Button("Open System Settings") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
              NSWorkspace.shared.open(url)
            }
          }
          .buttonStyle(.borderedProminent)
        }
      }

      if let image = capture.capturedImage {
        VStack(spacing: 12) {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 300)
            .cornerRadius(8)
            .shadow(radius: 4)

          HStack(spacing: 12) {
            Button("Use This Screenshot") {
              if let base64URL = capture.convertToBase64DataURL(image) {
                onImageCaptured(base64URL)
                dismiss()
              }
            }
            .buttonStyle(.borderedProminent)

            Button("Retake") {
              capture.clearImage()
            }
            .buttonStyle(.bordered)
          }
        }
      } else {
        VStack(spacing: 16) {
          Button("Capture Full Screen") {
            Task {
              await capture.captureScreenshot()
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(capture.isCapturing)

          if !availableWindows.isEmpty {
            Divider()

            Text("Or capture a specific window:")
              .font(.caption)
              .foregroundColor(.secondary)

            Picker("Select Window", selection: $selectedWindow) {
              Text("Choose a window...").tag(nil as SCWindow?)
              ForEach(availableWindows, id: \.windowID) { window in
                if let appName = window.owningApplication?.applicationName,
                   let title = window.title {
                  Text("\(appName): \(title)")
                    .tag(window as SCWindow?)
                } else {
                  Text(window.title ?? "Untitled Window")
                    .tag(window as SCWindow?)
                }
              }
            }
            .labelsHidden()

            if selectedWindow != nil {
              Button("Capture Selected Window") {
                if let window = selectedWindow {
                  Task {
                    await capture.captureWindow(window)
                  }
                }
              }
              .buttonStyle(.bordered)
              .disabled(capture.isCapturing)
            }
          }
        }
      }

      if capture.isCapturing {
        ProgressView("Capturing...")
          .padding()
      }
    }
    .padding()
    .frame(width: 500)
    .task {
      await loadAvailableWindows()
    }
  }

  private func loadAvailableWindows() async {
    do {
      // Get available content - this will trigger permission dialog on first use
      let content = try await SCShareableContent.current

      availableWindows = content.windows.filter { window in
        // Exclude our own app
        guard window.owningApplication?.applicationName != "CodeWhisper" else { return false }

        // Require a non-empty title
        guard let title = window.title, !title.isEmpty else { return false }

        // Filter out tiny windows (likely cursors, icons, UI elements)
        // Minimum size of 200x200 pixels for a meaningful window
        let minSize: CGFloat = 200
        guard window.frame.width >= minSize && window.frame.height >= minSize else { return false }

        // Only include windows that are on-screen
        guard window.isOnScreen else { return false }

        // Exclude system processes and common utilities
        if let appName = window.owningApplication?.applicationName {
          let systemApps = ["Window Server", "Dock", "SystemUIServer", "ControlCenter",
                           "Notification Center", "Spotlight", "Siri"]
          if systemApps.contains(appName) { return false }
        }

        return true
      }

      // Sort windows by application name, then by title for better organization
      availableWindows.sort { lhs, rhs in
        let lhsApp = lhs.owningApplication?.applicationName ?? ""
        let rhsApp = rhs.owningApplication?.applicationName ?? ""

        if lhsApp != rhsApp {
          return lhsApp < rhsApp
        }
        return (lhs.title ?? "") < (rhs.title ?? "")
      }
    } catch {
      // Silently fail to load windows - user can still capture full screen
      // If permission was denied, they'll get a proper error when they try to capture
    }
  }
}
