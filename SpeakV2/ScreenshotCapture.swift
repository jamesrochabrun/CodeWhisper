//
//  ScreenshotCapture.swift
//  SpeakV2
//
//  Screenshot capture utility for macOS
//

import Foundation
import AppKit
import ScreenCaptureKit
import Observation

@Observable
@MainActor
class ScreenshotCapture {
  var capturedImage: NSImage?
  var isCapturing = false
  var errorMessage: String?

  /// Capture a screenshot using the system screenshot picker
  func captureScreenshot() async {
    isCapturing = true
    errorMessage = nil

    do {
      // Get available content for screen capture
      // This will automatically prompt for permission on first use
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
      errorMessage = "Failed to capture screenshot: \(error.localizedDescription)"
      isCapturing = false
    }
  }

  /// Capture a specific window
  func captureWindow(_ window: SCWindow) async {
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
      errorMessage = "Failed to capture window: \(error.localizedDescription)"
      isCapturing = false
    }
  }

  /// Convert NSImage to base64 data URL for OpenAI API
  func convertToBase64DataURL(_ image: NSImage, format: ImageFormat = .png, quality: CGFloat = 0.8) -> String? {
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
  func clearImage() {
    capturedImage = nil
    errorMessage = nil
  }

  enum ImageFormat {
    case png
    case jpeg
  }
}

// MARK: - Screenshot Picker View

import SwiftUI

struct ScreenshotPickerView: View {
  @State private var capture = ScreenshotCapture()
  @Environment(\.dismiss) private var dismiss
  @State private var selectedWindow: SCWindow?
  @State private var availableWindows: [SCWindow] = []

  let onImageCaptured: (String) -> Void

  var body: some View {
    VStack(spacing: 20) {
      Text("Capture Screenshot")
        .font(.title2)
        .fontWeight(.semibold)

      if let errorMessage = capture.errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
          .padding()
          .background(Color.red.opacity(0.1))
          .cornerRadius(8)
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
                Text(window.title ?? "Untitled Window")
                  .tag(window as SCWindow?)
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
      // Get available content - this will prompt for permission on first use
      let content = try await SCShareableContent.current
      availableWindows = content.windows.filter { window in
        window.owningApplication?.applicationName != "SpeakV2" &&
        window.title != nil &&
        !window.title!.isEmpty
      }
    } catch {
      capture.errorMessage = "Failed to load windows: \(error.localizedDescription)"
    }
  }
}
