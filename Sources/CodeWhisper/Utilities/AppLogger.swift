//
//  AppLogger.swift
//  CodeWhisper
//
//  Created by James Rochabrun on 2024.
//

import Foundation
import os

/// App-wide logger using Apple's unified logging system
/// Usage: AppLogger.info("Message") or AppLogger.error("Error occurred")
public enum AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.codewhisper"
    private static let logger = Logger(subsystem: subsystem, category: "app")

    /// Debug-level logging (verbose, only visible with Console.app filters)
    public static func debug(_ message: String, file: String = #file) {
        let category = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        logger.debug("[\(category)] \(message)")
    }

    /// Info-level logging (general information)
    public static func info(_ message: String, file: String = #file) {
        let category = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        logger.info("[\(category)] \(message)")
    }

    /// Warning-level logging (potential issues)
    public static func warning(_ message: String, file: String = #file) {
        let category = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        logger.warning("[\(category)] \(message)")
    }

    /// Error-level logging (failures and errors)
    public static func error(_ message: String, file: String = #file) {
        let category = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        logger.error("[\(category)] \(message)")
    }
}
