//
//  STTRecorder.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/28/25.
//

import Foundation
@preconcurrency import AVFoundation
import SwiftOpenAI

/// Simple audio recorder for speech-to-text using AVAudioEngine.
/// Provides a straightforward way to capture microphone audio as PCM buffers.
@RealtimeActor
public final class STTRecorder {

  private var audioEngine: AVAudioEngine?
  private var isRecording = false

  public init() {}

  /// Start recording and return an AsyncStream of PCM buffers
  /// - Returns: An AsyncStream that yields AVAudioPCMBuffer as audio is captured
  /// - Throws: If the audio engine fails to start
  public func startRecording() throws -> AsyncStream<AVAudioPCMBuffer> {
    // Clean up any previous session
    if isRecording {
      stopRecording()
    }

    // Create fresh audio engine to avoid HAL state corruption
    let engine = AVAudioEngine()
    self.audioEngine = engine

    // On macOS, explicitly set input to built-in microphone when Bluetooth headphones are connected
    #if os(macOS)
    configureBuiltInMicrophoneIfNeeded(for: engine)
    #endif

    let inputNode = engine.inputNode

    // IMPORTANT: Get format AFTER configuring input device, as format may change
    // Use the hardware format to avoid format mismatch errors
    let hardwareFormat = inputNode.inputFormat(forBus: 0)
    let format: AVAudioFormat
    if hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 {
      format = hardwareFormat
    } else {
      format = inputNode.outputFormat(forBus: 0)
    }
    // Create stream
    let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()

    // Install tap on input node using the correct format
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      continuation.yield(buffer)
    }

    // Prepare and start
    engine.prepare()
    try engine.start()
    isRecording = true

    // Handle termination
    continuation.onTermination = { [weak self] _ in
      Task { @RealtimeActor in
        self?.stopRecording()
      }
    }

    return stream
  }

  /// Stop recording and clean up resources
  public func stopRecording() {
    guard isRecording, let engine = audioEngine else { return }

    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    audioEngine = nil
    isRecording = false
  }

  // MARK: - Private

  #if os(macOS)
  /// Configure the audio engine to use the built-in microphone instead of Bluetooth mic
  private func configureBuiltInMicrophoneIfNeeded(for engine: AVAudioEngine) {
    var deviceID: AudioDeviceID = 0
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    // Get the default input device
    var propertyAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &deviceID
    )

    guard status == noErr else { return }

    // Check if the default input device is a Bluetooth device by checking transport type
    var transportType: UInt32 = 0
    propertySize = UInt32(MemoryLayout<UInt32>.size)
    propertyAddress.mSelector = kAudioDevicePropertyTransportType
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal

    let transportStatus = AudioObjectGetPropertyData(
      deviceID,
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &transportType
    )

    if transportStatus == noErr && transportType == kAudioDeviceTransportTypeBluetooth {
      // Find the built-in microphone
      if let builtInMicID = findBuiltInMicrophone() {
        do {
          try engine.inputNode.setVoiceProcessingEnabled(false)
          // Set the input device on the audio unit
          var inputDeviceID = builtInMicID
          guard let audioUnit = engine.inputNode.audioUnit else { return }

          let setStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &inputDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
          )

          // If device switch succeeded, uninitialize and reinitialize to apply changes
          if setStatus == noErr {
            AudioUnitUninitialize(audioUnit)
            AudioUnitInitialize(audioUnit)
          }
        } catch {
          // Silently fall back to default input
        }
      }
    }
  }

  /// Find the built-in microphone device ID
  private func findBuiltInMicrophone() -> AudioDeviceID? {
    var propertyAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var propertySize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      &propertySize
    )

    guard status == noErr else { return nil }

    let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
    var devices = [AudioDeviceID](repeating: 0, count: deviceCount)

    status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &devices
    )

    guard status == noErr else { return nil }

    // Find a device with "Built-in" in the name that has input channels
    for device in devices {
      // Check if device has input channels
      var inputChannelsAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
      )

      var bufferListSize: UInt32 = 0
      status = AudioObjectGetPropertyDataSize(device, &inputChannelsAddress, 0, nil, &bufferListSize)
      guard status == noErr, bufferListSize > 0 else { continue }

      let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
      defer { bufferListPointer.deallocate() }

      status = AudioObjectGetPropertyData(device, &inputChannelsAddress, 0, nil, &bufferListSize, bufferListPointer)
      guard status == noErr else { continue }

      let bufferList = bufferListPointer.pointee
      guard bufferList.mNumberBuffers > 0, bufferList.mBuffers.mNumberChannels > 0 else { continue }

      // Check transport type - we want built-in devices
      var transportType: UInt32 = 0
      var transportSize = UInt32(MemoryLayout<UInt32>.size)
      var transportAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyTransportType,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )

      status = AudioObjectGetPropertyData(device, &transportAddress, 0, nil, &transportSize, &transportType)
      if status == noErr && transportType == kAudioDeviceTransportTypeBuiltIn {
        return device
      }
    }

    return nil
  }
  #endif
}
