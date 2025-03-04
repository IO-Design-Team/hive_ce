import 'dart:isolate';

import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import '../integration/integration.dart';

void main() async {
  Future<void> runIsolate(HiveImpl hive) {
    return Isolate.run(() async {
      final box = await hive.openBox<int>('test');
      for (var i = 0; i < 1000; i++) {
        await box.put(i, i);
      }
    });
  }

  group('isolates', () {
    test('single', () async {
      final hive = await createHive();
      expect(runIsolate(hive), completes);
    });

    test('multiple', () async {
      final hive = await createHive();
      expect(
        Future.wait([for (var i = 0; i < 100; i++) runIsolate(hive)]),
        completes,
      );
    });
  });
}
