import 'dart:isolate';

import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

/// Base class for managing the Hive isolate
///
/// Used for testing
abstract class HiveIsolate {
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
