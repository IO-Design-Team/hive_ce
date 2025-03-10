import 'dart:isolate';

import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() async {
  Future<void> runIsolate(String path, int index) {
    return Isolate.run(() async {
      final hive = IsolatedHive();
      await hive.init(path);
      final box = await hive.openBox<int>('test');
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
        await expectLater(runIsolate(dir.path, 0), completes);
        Hive.init(dir.path);
        final box = await Hive.openBox<int>('test');
        expect(box.length, 100);
      });

      test('multiple', () async {
        final dir = await getTempDir();
        await expectLater(
          Future.wait([for (var i = 0; i < 100; i++) runIsolate(dir.path, i)]),
          completes,
        );
        Hive.init(dir.path);
        final box = await Hive.openBox<int>('test');
        expect(box.length, 10000);
      });
    },
    onPlatform: {
      'chrome': Skip('Isolates are not supported on web'),
    },
  );
}
