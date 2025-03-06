import 'dart:isolate';

import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() async {
  Future<void> runIsolate() async {
    final dir = await getTempDir();
    return Isolate.run(() async {
      Hive.init(dir.path);
      final box = await Hive.openBox<int>('test');
      for (var i = 0; i < 1000; i++) {
        await box.put(i, i);
      }
    });
  }

  group('isolates', () {
    test('single', () {
      expect(runIsolate(), completes);
    });

    test('multiple', () {
      expect(
        Future.wait([for (var i = 0; i < 100; i++) runIsolate()]),
        completes,
      );
    });
  });
}
