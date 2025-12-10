//
//  FloatingSTTConfiguration.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 12/9/25.
//

#if os(macOS)
import Foundation
import CoreGraphics

/// Configuration for the floating STT button
public struct FloatingSTTConfiguration: Codable, Sendable, Equatable {

    // MARK: - Properties

    /// Width of the floating button (horizontal capsule)
    public var buttonWidth: CGFloat

    /// Height of the floating button (horizontal capsule)
    public var buttonHeight: CGFloat

    /// Last saved position of the button
    public var position: CGPoint

    /// Whether to remember the button position between sessions
    public var rememberPosition: Bool

    /// Preferred text insertion method
    public var preferredInsertionMethod: TextInsertionMethod

    /// Whether to show visual feedback on insertion success/failure
    public var showVisualFeedback: Bool

    /// Opacity of the button when idle (0.0 - 1.0)
    public var idleOpacity: CGFloat

    // MARK: - Computed Properties

    /// Size as CGSize for convenience
    public var buttonSize: CGSize {
        CGSize(width: buttonWidth, height: buttonHeight)
    }

    // MARK: - Initialization

    public init(
        buttonWidth: CGFloat = 72,
        buttonHeight: CGFloat = 44,
        position: CGPoint = CGPoint(x: 20, y: 100),
        rememberPosition: Bool = true,
        preferredInsertionMethod: TextInsertionMethod = .accessibilityAPI,
        showVisualFeedback: Bool = true,
        idleOpacity: CGFloat = 1.0
    ) {
        self.buttonWidth = buttonWidth
        self.buttonHeight = buttonHeight
        self.position = position
        self.rememberPosition = rememberPosition
        self.preferredInsertionMethod = preferredInsertionMethod
        self.showVisualFeedback = showVisualFeedback
        self.idleOpacity = idleOpacity
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case buttonWidth
        case buttonHeight
        case buttonSize // Legacy support
        case positionX
        case positionY
        case rememberPosition
        case preferredInsertionMethod
        case showVisualFeedback
        case idleOpacity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Support both new (width/height) and legacy (size) formats
        if let width = try container.decodeIfPresent(CGFloat.self, forKey: .buttonWidth),
           let height = try container.decodeIfPresent(CGFloat.self, forKey: .buttonHeight) {
            buttonWidth = width
            buttonHeight = height
        } else if let legacySize = try container.decodeIfPresent(CGFloat.self, forKey: .buttonSize) {
            // Migrate from legacy square button to horizontal capsule
            buttonWidth = legacySize * 1.3  // Wider
            buttonHeight = legacySize * 0.8 // Shorter
        } else {
            buttonWidth = 72
            buttonHeight = 44
        }

        let x = try container.decode(CGFloat.self, forKey: .positionX)
        let y = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)
        rememberPosition = try container.decode(Bool.self, forKey: .rememberPosition)
        preferredInsertionMethod = try container.decode(TextInsertionMethod.self, forKey: .preferredInsertionMethod)
        showVisualFeedback = try container.decode(Bool.self, forKey: .showVisualFeedback)
        idleOpacity = try container.decodeIfPresent(CGFloat.self, forKey: .idleOpacity) ?? 1.0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buttonWidth, forKey: .buttonWidth)
        try container.encode(buttonHeight, forKey: .buttonHeight)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(rememberPosition, forKey: .rememberPosition)
        try container.encode(preferredInsertionMethod, forKey: .preferredInsertionMethod)
        try container.encode(showVisualFeedback, forKey: .showVisualFeedback)
        try container.encode(idleOpacity, forKey: .idleOpacity)
    }

    // MARK: - Defaults

    /// Default configuration
    public static let `default` = FloatingSTTConfiguration()
}
#endif
