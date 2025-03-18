import 'dart:isolate';

import 'package:hive_ce/hive.dart';

class StubIns extends IsolateNameServer {
  @override
  SendPort? lookupPortByName(String name) => throw UnimplementedError();

  @override
  bool registerPortWithName(SendPort port, String name) =>
      throw UnimplementedError();

  @override
  bool removePortNameMapping(String name) => throw UnimplementedError();
}
