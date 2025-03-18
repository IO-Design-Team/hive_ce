import 'dart:isolate';

import 'package:hive_ce/hive.dart';

class TestNameServer extends IsolateNameServer {
  final ports = <String, SendPort>{};

  @override
  SendPort? lookupPortByName(String name) => ports[name];

  @override
  bool registerPortWithName(SendPort port, String name) {
    ports[name] = port;
    return true;
  }

  @override
  bool removePortNameMapping(String name) => ports.remove(name) != null;
}

void main() async {
  await IsolatedHive.init('.', isolateNameServer: TestNameServer());
  final box = await IsolatedHive.openBox('box');
  await box.put('key', 'value');
  print(await box.get('key')); // reading is async
}
