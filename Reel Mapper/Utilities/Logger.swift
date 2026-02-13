import Foundation
import os.log

/// Centralized logging utility for Reel Mapper
///
/// Provides structured logging with different severity levels and categories.
/// Debug logs are automatically suppressed in Release builds.
struct AppLogger {
    private static let subsystem = "com.reelmapper.app"

    // Log categories
    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let ui = Logger(subsystem: subsystem, category: "ui")

    // MARK: - Debug Level (suppressed in Release builds)

    /// Log debug information (only in DEBUG builds)
    static func debug(_ message: String, category: Logger = .network) {
        #if DEBUG
        category.debug("\(message)")
        #endif
    }

    // MARK: - Info Level

    /// Log informational messages
    static func info(_ message: String, category: Logger = .network) {
        category.info("\(message)")
    }

    // MARK: - Warning Level

    /// Log warning messages
    static func warning(_ message: String, category: Logger = .network) {
        category.warning("\(message)")
    }

    // MARK: - Error Level

    /// Log error messages
    static func error(_ message: String, category: Logger = .network) {
        category.error("\(message)")
    }

    // MARK: - Sensitive Data Handling

    /// Log with automatic redaction of sensitive data in Release builds
    static func debugSensitive(_ message: String, category: Logger = .network) {
        #if DEBUG
        category.debug("\(message)")
        #else
        category.debug("[REDACTED]")
        #endif
    }
}
