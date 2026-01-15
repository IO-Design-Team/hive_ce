import 'package:hive_ce/src/isolate/isolate_debug_name/isolate_debug_name.dart';
import 'package:hive_ce/src/util/debug_utils.dart';

/// Configures the logging behavior of Hive
abstract class Logger {
  /// The overall logging level
  static var level = kDebugMode ? LoggerLevel.debug : LoggerLevel.info;

  /// If the unsafe isolate warning is enabled
  static var unsafeIsolateWarning = true;

  /// If the unmatched isolation warning is enabled
  static var unmatchedIsolationWarning = true;

  /// If the no isolate name server warning is enabled
  static var noIsolateNameServerWarning = true;

  /// If the crc recalculation warning is enabled
  static var crcRecalculationWarning = true;

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

/// Warning messages from Hive
abstract class HiveWarning {
  const HiveWarning._();

  /// Warning message printed when attempting to store an integer that is too large
  static const bigInt =
      'WARNING: Writing integer values greater than 2^53 will result in precision loss.'
      ' This is due to Hive storing all numbers as 64 bit floats.'
      ' Consider using a BigInt.';

  /// Warning message printed when accessing Hive from an unsafe isolate
  static final unsafeIsolate = '''
⚠️ WARNING: HIVE MULTI-ISOLATE RISK DETECTED ⚠️

Accessing Hive from an unsafe isolate (current isolate: "$isolateDebugName")
This can lead to DATA CORRUPTION as Hive boxes are not designed for concurrent
access across isolates. Each isolate would maintain its own box cache,
potentially causing data inconsistency and corruption.

RECOMMENDED ACTIONS:
- Use IsolatedHive instead

''';

  /// Warning for existing lock of unmatched isolation
  static const unmatchedIsolation = '''
⚠️ WARNING: HIVE MULTI-ISOLATE RISK DETECTED ⚠️

You are opening this box with Hive, but this box was previously opened with
IsolatedHive. This can lead to DATA CORRUPTION as Hive boxes are not designed
for concurrent access across isolates. Each isolate would maintain its own box
cache, potentially causing data inconsistency and corruption.

RECOMMENDED ACTIONS:
- ALWAYS use IsolatedHive to perform box operations when working with multiple
  isolates
''';

  /// Warning message printed when using [IsolatedHive] without an [IsolateNameServer]
  static final noIsolateNameServer = '''
⚠️ WARNING: HIVE MULTI-ISOLATE RISK DETECTED ⚠️

Using IsolatedHive without an IsolateNameServer is unsafe. This can lead to
DATA CORRUPTION as Hive boxes are not designed for concurrent access across
isolates. Using an IsolateNameServer allows IsolatedHive to maintain a single
isolate for all Hive operations.

RECOMMENDED ACTIONS:
- Initialize IsolatedHive with IsolatedHive.initFlutter from hive_ce_flutter
- Provide your own IsolateNameServer

''';

  /// Warning message printed when CRC recalculation is needed
  static const crcRecalculationNeeded =
      'WARNING: CRC recalculation needed for frame.'
      ' This happens when IsolatedHive was used with encryption before it was properly handled.'
      ' IsolatedHive will continue to work, but read performance may be degraded for old entries.'
      ' To restore performance, rewrite all box entries.'
      ' This only needs to be done once.'
      '\n\nEXAMPLE\n\n'
      '''
for (final key in await box.keys) {
  await box.put(key, await box.get(key));
}''';
}
