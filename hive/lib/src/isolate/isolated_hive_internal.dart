part of 'isolated_hive.dart';

/// Internal methods for [IsolatedHive]
extension IsolatedHiveInternal on IsolatedHive {
  /// Set the entry point for the isolate for testing purposes
  @visibleForTesting
  set entryPoint(IsolateEntryPoint entryPoint) => _entryPoint = entryPoint;

  /// Access to the isolate connection for testing purposes
  @visibleForTesting
  IsolateConnection get connection => _connection;
}
