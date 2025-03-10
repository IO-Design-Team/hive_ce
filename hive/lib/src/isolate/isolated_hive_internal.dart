part of 'isolated_hive.dart';

/// Internal methods for [IsolatedHive]
extension IsolatedHiveInternal on IsolatedHive {
  /// Set the entry point for the isolate for testing purposes
  @visibleForTesting
  void setEntryPoint(IsolateEntryPoint entryPoint) => _entryPoint = entryPoint;
}
