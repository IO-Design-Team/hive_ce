import 'dart:isolate';

import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import 'common.dart';

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

void main() async {
  Future<void> runIsolate(TestIns ins, String path, int index) {
    return Isolate.run(() async {
      final hive = IsolatedHive(isolateNameServer: ins);
      await hive.init(path);
      final box = hive.box<int>('test');
      final start = index * 100;
      final end = start + 100;
      for (var i = start; i < end; i++) {
        await box.put(i, i);
      }
    });
  }

  group(
    'isolates',
    () {
      test('single', () async {
        final dir = await getTempDir();
        final ins = TestIns();
        final hive = IsolatedHive(isolateNameServer: ins);
        await hive.init(dir.path);
        final box = await hive.openBox<int>('test');
        await expectLater(runIsolate(ins, dir.path, 0), completes);
        expect(await box.length, 100);
      });

      test('multiple', () async {
        final dir = await getTempDir();
        final ins = TestIns();
        final hive = IsolatedHive(isolateNameServer: ins);
        await hive.init(dir.path);
        final box = await hive.openBox<int>('test');
        await expectLater(
          Future.wait(
            [for (var i = 0; i < 100; i++) runIsolate(ins, dir.path, i)],
          ),
          completes,
        );
        expect(await box.length, 10000);
      });
    },
    onPlatform: {
      'chrome': Skip('Isolates are not supported on web'),
    },
  );
}
