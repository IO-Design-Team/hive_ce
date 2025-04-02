import 'dart:isolate';

import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

/// Base class for managing the Hive isolate
///
/// Used for testing
abstract class HiveIsolate {
  /// The name of the hive isolate
  static const isolateName = '_hive_isolate';

  /// Warning message printed when using [IsolatedHive] without an [IsolateNameServer]
  static final noIsolateNameServerWarning = '''
⚠️ WARNING: HIVE MULTI-ISOLATE RISK DETECTED ⚠️

Using IsolatedHive without an IsolateNameServer is unsafe. This can lead to
DATA CORRUPTION as Hive boxes are not designed for concurrent access across
isolates. Using an IsolateNameServer allows IsolatedHive to maintain a single
isolate for all Hive operations.

RECOMMENDED ACTIONS:
- Initialize IsolatedHive with IsolatedHive.initFlutter from hive_ce_flutter
- Provide your own IsolateNameServer

''';

  /// Access to the isolate connection for testing
  @visibleForTesting
  IsolateConnection get connection;

  /// Override the isolate spawn method for testing
  @visibleForTesting
  set spawnHiveIsolate(Future<IsolateConnection> Function() spawnHiveIsolate);

  /// Called when the hive isolate connects
  @visibleForTesting
  void onConnect(SendPort send);

  /// Called when the hive isolate exits
  @visibleForTesting
  void onExit();
}
