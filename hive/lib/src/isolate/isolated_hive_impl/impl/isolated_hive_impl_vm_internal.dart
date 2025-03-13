part of 'isolated_hive_impl_vm.dart';

/// Internal methods for [IsolatedHive]
extension IsolatedHiveInternal on IsolatedHiveImpl {
  /// Set the entry point for the isolate for testing purposes
  @visibleForTesting
  set entryPoint(IsolateEntryPoint entryPoint) => _entryPoint = entryPoint;

  /// Access to the isolate connection for testing purposes
  @visibleForTesting
  IsolateConnection get connection => _connection;
}
