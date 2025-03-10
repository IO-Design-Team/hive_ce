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
  Future<void> runIsolate({
    IsolateNameServer? ins,
    required String path,
  }) {
    return Isolate.run(() async {
      final hive = IsolatedHive(isolateNameServer: ins);
      await hive.init(path);
      final box = await hive.openBox<int>('test');
      for (var i = 0; i < 100; i++) {
        await box.add(i);
      }
    });
  }

  group(
    'isolates',
    () {
      test('single without INS', () async {
        final dir = await getTempDir();
        final hive = IsolatedHive();
        await hive.init(dir.path);
        await expectLater(runIsolate(path: dir.path), completes);
        final box = await hive.openBox<int>('test');
        expect(await box.length, 100);
      });

      group('multiple', () {
        test('without INS', () async {
          final dir = await getTempDir();
          final hive = IsolatedHive();
          await hive.init(dir.path);
          await expectLater(
            Future.wait([
              for (var i = 0; i < 100; i++) runIsolate(path: dir.path),
            ]),
            completes,
          );
          final box = await hive.openBox<int>('test');
          expect(await box.length, isNot(10000));
        });

        test('with INS', () async {
          final dir = await getTempDir();
          final ins = TestIns();
          final hive = IsolatedHive(isolateNameServer: ins);
          await hive.init(dir.path);
          await expectLater(
            Future.wait([
              for (var i = 0; i < 100; i++)
                runIsolate(ins: ins, path: dir.path),
            ]),
            completes,
          );
          final box = await hive.openBox<int>('test');
          expect(await box.length, 10000);
        });
      });
    },
    onPlatform: {
      'chrome': Skip('Isolates are not supported on web'),
    },
  );
}
