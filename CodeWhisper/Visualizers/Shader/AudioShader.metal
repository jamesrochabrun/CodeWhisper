//
//  AudioShader.metal
//  CodeWhisper
//
//  Created by James Rochabrun on 11/9/25.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Audio data passed from CPU
struct AudioData {
    float userLevel;        // User mic amplitude
    float aiLevel;          // AI speech amplitude
    float lowFreq;          // Low frequency band (0-250Hz)
    float midFreq;          // Mid frequency band (250-2000Hz)
    float highFreq;         // High frequency band (2000Hz+)
    float conversationState; // 0=idle, 1=user, 2=aiThinking, 3=aiSpeaking
    float time;             // Elapsed time
};

// Vertex shader
vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0)
    };

    float2 texCoords[6] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0, 0.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

// SIMPLE TEST: Just draw a bright circle
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant AudioData &audio [[buffer(0)]]) {
    // Center coordinates: convert from [0,1] to [-1,1]
    float2 uv = in.texCoord * 2.0 - 1.0;

    // Distance from center
    float dist = length(uv);

    // Simple circle: white inside radius 0.5, fade to black outside
    float circle = 1.0 - smoothstep(0.4, 0.5, dist);

    // Bright cyan color
    float3 color = float3(0.0, 1.0, 1.0);

    return float4(color * circle, 1.0);
}
