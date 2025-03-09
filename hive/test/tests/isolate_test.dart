import 'dart:isolate';

import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() async {
  Future<void> runIsolate(String path) {
    return Isolate.run(() async {
      final hive = IsolatedHive();
      await hive.init(path);
      final box = await hive.openBox<int>('test');
      for (var i = 0; i < 1000; i++) {
        await box.put(i, i);
      }
    });
  }

  group(
    'isolates',
    () {
      test('single', () async {
        final dir = await getTempDir();
        expect(runIsolate(dir.path), completes);
      });

      test('multiple', () async {
        final dir = await getTempDir();
        expect(
          Future.wait([for (var i = 0; i < 100; i++) runIsolate(dir.path)]),
          completes,
        );
      });
    },
    onPlatform: {
      'chrome': Skip('Isolates are not supported on web'),
    },
  );
}
