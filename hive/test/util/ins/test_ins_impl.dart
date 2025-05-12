import 'dart:isolate';

import 'package:hive_ce/hive.dart';

/// Exists to silence the warning about not passing an INS
class StubIns extends IsolateNameServer {
  @override
  SendPort? lookupPortByName(String name) => null;

  @override
  bool registerPortWithName(SendPort port, String name) => true;

  @override
  bool removePortNameMapping(String name) => true;
}

class TestIns extends IsolateNameServer {
  final _ports = <String, SendPort>{};

  @override
  SendPort? lookupPortByName(String name) => _ports[name];

  @override
  bool registerPortWithName(SendPort port, String name) {
    _ports[name] = port;
    return true;
  }

  @override
  bool removePortNameMapping(String name) {
    _ports.remove(name);
    return true;
  }
}