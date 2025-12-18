import 'package:hive_ce/src/util/debug_utils.dart';

/// Configures the logging behavior of Hive
final class Logger {
  /// The overall logging level
  static var level = kDebugMode ? LoggerLevel.debug : LoggerLevel.info;

  /// If the unsafe isolate warning is enabled
  static var unsafeIsolateWarning = true;

  /// Log a verbose message
  static void v(Object? message) {
    if (level.index > LoggerLevel.verbose.index) return;
    print(message);
  }

  /// Log a debug message
  static void d(Object? message) {
    if (level.index > LoggerLevel.debug.index) return;
    print(message);
  }

  /// Log an informational message
  static void i(Object? message) {
    if (level.index > LoggerLevel.info.index) return;
    print(message);
  }

  /// Log a warning message
  static void w(Object? message) {
    if (level.index > LoggerLevel.warn.index) return;
    print(message);
  }

  /// Log an error message
  static void e(Object? message) {
    if (level.index > LoggerLevel.error.index) return;
    print(message);
  }

  /// Log a message for an event that should not be possible
  static void wtf(Object? message) => print(message);
}

/// Logging levels for Hive
enum LoggerLevel {
  /// All log messages
  verbose,

  /// Debug log messages
  debug,

  /// Informational log messages
  info,

  /// Warnings
  warn,

  /// Errors
  error;
}
