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

    /// Size of the floating button (diameter in points)
    public var buttonSize: CGFloat

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

    // MARK: - Initialization

    public init(
        buttonSize: CGFloat = 56,
        position: CGPoint = CGPoint(x: 100, y: 300),
        rememberPosition: Bool = true,
        preferredInsertionMethod: TextInsertionMethod = .accessibilityAPI,
        showVisualFeedback: Bool = true,
        idleOpacity: CGFloat = 1.0
    ) {
        self.buttonSize = buttonSize
        self.position = position
        self.rememberPosition = rememberPosition
        self.preferredInsertionMethod = preferredInsertionMethod
        self.showVisualFeedback = showVisualFeedback
        self.idleOpacity = idleOpacity
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case buttonSize
        case positionX
        case positionY
        case rememberPosition
        case preferredInsertionMethod
        case showVisualFeedback
        case idleOpacity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buttonSize = try container.decode(CGFloat.self, forKey: .buttonSize)
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
        try container.encode(buttonSize, forKey: .buttonSize)
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
