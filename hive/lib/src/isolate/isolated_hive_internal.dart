part of 'isolated_hive.dart';

extension IsolatedHiveInternal on IsolatedHive {
  void setEntryPoint(IsolateEntryPoint entryPoint) => _entryPoint = entryPoint;
}
