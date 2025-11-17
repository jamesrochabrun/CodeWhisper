//
//  MetalAudioVisualizerView.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

import SwiftUI
import MetalKit

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

// Audio data struct matching Metal shader
struct AudioData {
    var userLevel: Float        // User mic amplitude
    var aiLevel: Float          // AI speech amplitude
    var lowFreq: Float          // Low frequency band (0-250Hz)
    var midFreq: Float          // Mid frequency band (250-2000Hz)
    var highFreq: Float         // High frequency band (2000Hz+)
    var conversationState: Float // 0=idle, 1=user, 2=aiThinking, 3=aiSpeaking
    var time: Float             // Elapsed time
}

struct MetalAudioVisualizerView: PlatformViewRepresentable {
    let conversationManager: ConversationManager

    func makeCoordinator() -> Coordinator {
        Coordinator(conversationManager: conversationManager)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> MTKView {
        print("🔵 makeNSView called - creating MTKView")
        let mtkView = MTKView()
        mtkView.device = context.coordinator.device
        mtkView.delegate = context.coordinator

        // CRITICAL: Set pixel format BEFORE other properties
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .invalid

        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1) // TEST: Bright red

        // CRITICAL: macOS NSView configuration for visibility
        mtkView.wantsLayer = true
        mtkView.layer?.isOpaque = true
        mtkView.layerContentsRedrawPolicy = .duringViewResize
        mtkView.framebufferOnly = false
        mtkView.autoResizeDrawable = true

        print("🔵 MTKView created with frame: \(mtkView.frame), bounds: \(mtkView.bounds)")
        print("🔵 MTKView colorPixelFormat: \(mtkView.colorPixelFormat.rawValue)")
        print("🔵 MTKView drawableSize: \(mtkView.drawableSize)")
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Data is pulled from conversation manager in draw()
    }
    #else
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = context.coordinator.device
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        // Data is pulled from conversation manager in draw()
    }
    #endif

    @MainActor
    class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipelineState: MTLRenderPipelineState
        let conversationManager: ConversationManager
        var startTime: CFAbsoluteTime
        var hasLoggedFirstDraw = false
        var hasLoggedDrawable = false
        var noDrawableCount = 0

        init(conversationManager: ConversationManager) {
            self.conversationManager = conversationManager
            self.startTime = CFAbsoluteTimeGetCurrent()

            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal is not supported on this device")
            }
            print("✅ Metal device created: \(device.name)")

            guard let commandQueue = device.makeCommandQueue() else {
                fatalError("Failed to create command queue")
            }
            print("✅ Command queue created")

            self.device = device
            self.commandQueue = commandQueue

            // Create pipeline state
            guard let library = device.makeDefaultLibrary() else {
                fatalError("Failed to create default Metal library")
            }
            print("✅ Metal library created")

            guard let vertexFunction = library.makeFunction(name: "vertexShader") else {
                fatalError("Failed to create vertexShader function")
            }
            print("✅ Vertex shader function found")

            guard let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
                fatalError("Failed to create fragmentShader function")
            }
            print("✅ Fragment shader function found")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            do {
                self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                print("✅ Pipeline state created successfully")
            } catch {
                print("❌ Failed to create pipeline state: \(error)")
                fatalError("Failed to create pipeline state: \(error)")
            }

            super.init()
            print("✅ Coordinator initialized successfully")
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("🔵 MTKView size changed to: \(size)")
            print("🔵 View's drawableSize: \(view.drawableSize)")
            print("🔵 View's bounds: \(view.bounds)")
        }

        func draw(in view: MTKView) {
            // Debug: Log once at start
            if !hasLoggedFirstDraw {
                print("🔍 FIRST DRAW - View drawableSize: \(view.drawableSize)")
                print("🔍 FIRST DRAW - View bounds: \(view.bounds)")
                print("🔍 FIRST DRAW - View frame: \(view.frame)")
                hasLoggedFirstDraw = true
            }

            guard let drawable = view.currentDrawable else {
                noDrawableCount += 1
                if noDrawableCount < 5 {
                    print("⚠️ No drawable available (count: \(noDrawableCount))")
                }
                return
            }

            guard let descriptor = view.currentRenderPassDescriptor else {
                print("⚠️ No render pass descriptor")
                return
            }

            // Debug: Log drawable info once
            if !hasLoggedDrawable {
                print("🔍 Drawable texture size: \(drawable.texture.width)x\(drawable.texture.height)")
                print("🔍 Drawable pixel format: \(drawable.texture.pixelFormat.rawValue)")
                print("🔍 Clear color: R=\(descriptor.colorAttachments[0].clearColor.red) G=\(descriptor.colorAttachments[0].clearColor.green) B=\(descriptor.colorAttachments[0].clearColor.blue)")
                print("🔍 Load action: \(descriptor.colorAttachments[0].loadAction.rawValue)")
                hasLoggedDrawable = true
            }

            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                print("⚠️ Failed to create command buffer")
                return
            }

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                print("⚠️ Failed to create render encoder")
                return
            }

            renderEncoder.setRenderPipelineState(pipelineState)

            // Build audio data struct from conversation manager
            var audioData = AudioData(
                userLevel: conversationManager.audioLevel,
                aiLevel: conversationManager.aiAudioLevel,
                lowFreq: conversationManager.lowFrequency,
                midFreq: conversationManager.midFrequency,
                highFreq: conversationManager.highFrequency,
                conversationState: Float(conversationManager.conversationState.rawValue),
                time: Float(CFAbsoluteTimeGetCurrent() - startTime)
            )

            // Debug log once per second
            let currentTime = CFAbsoluteTimeGetCurrent()
            if Int(currentTime) != Int(startTime) && Int(currentTime) % 2 == 0 {
                print("🎨 Drawing: state=\(conversationManager.conversationState.rawValue) userLevel=\(audioData.userLevel) aiLevel=\(audioData.aiLevel) time=\(audioData.time)")
            }

            // Pass audio data struct to shader
            renderEncoder.setFragmentBytes(&audioData,
                                           length: MemoryLayout<AudioData>.size,
                                           index: 0)

            // Draw
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
