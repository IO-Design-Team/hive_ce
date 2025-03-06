import 'dart:isolate';

import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() async {
  Future<void> runIsolate(String path) {
    return Isolate.run(() async {
      final hive = HiveImpl()..init(path);
      final box = await hive.openBox<int>('test');
      await Future.wait([
        for (var i = 0; i < 1000; i++) box.put(i, i),
      ]);
    });
  }

  group('isolates', () {
    test('single', () async {
      final dir = await getTempDir();
      expect(runIsolate(dir.path), completes);
    });

    test(
      'multiple',
      () async {
        final dir = await getTempDir();
        expect(
          Future.wait([for (var i = 0; i < 1000; i++) runIsolate(dir.path)]),
          completes,
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
