@TestOn('vm')
library;

import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:test/test.dart';

import '../tests/common.dart';
import 'isolate_test.dart' show StubIns;

/// Puts [count] largish entries into [box] so that compaction has a
/// meaningful amount of data to reclaim
Future<void> _putEntries(IsolatedBox<String> box, int count) async {
  final value = 'x' * 1000;
  for (var i = 0; i < count; i++) {
    await box.put('key$i', value);
  }
}

Future<int> _fileSize(IsolatedBox box) async =>
    File((await box.path)!).length();

void main() {
  group('IsolatedCompactionStrategy', () {
    // This spawns a real isolate, so the IsolatedCompactionStrategy must be
    // correctly serialized to JSON, sent across the isolate boundary, and
    // resolved back into a real CompactionStrategy on the other side
    test('.threshold() compacts the box once exceeded', () async {
      final dir = await getTempDir();
      final hive = IsolatedHiveImpl();
      addTearDown(hive.close);
      await hive.init(dir.path, isolateNameServer: StubIns());

      final box = await hive.openBox<String>(
        'test',
        compactionStrategy: const IsolatedCompactionStrategy.threshold(
          deletedThreshold: 1,
          deletedRatio: 0,
        ),
      );

      await _putEntries(box, 10);
      final sizeAfterPuts = await _fileSize(box);

      for (var i = 0; i < 5; i++) {
        await box.delete('key$i');
      }

      expect(await box.length, 5);
      expect(await _fileSize(box), lessThan(sizeAfterPuts));
    });

    test('.never() never compacts the box', () async {
      final dir = await getTempDir();
      final hive = IsolatedHiveImpl();
      addTearDown(hive.close);
      await hive.init(dir.path, isolateNameServer: StubIns());

      final box = await hive.openBox<String>(
        'test',
        compactionStrategy: const IsolatedCompactionStrategy.never(),
      );

      await _putEntries(box, 10);
      final sizeAfterPuts = await _fileSize(box);

      for (var i = 0; i < 5; i++) {
        await box.delete('key$i');
      }

      expect(await box.length, 5);
      // Without compaction the file can only grow, since deleting an entry
      // appends a tombstone rather than reclaiming space
      expect(await _fileSize(box), greaterThanOrEqualTo(sizeAfterPuts));
    });

    test('.always() always compacts the box', () async {
      final dir = await getTempDir();
      final hive = IsolatedHiveImpl();
      addTearDown(hive.close);
      await hive.init(dir.path, isolateNameServer: StubIns());

      final box = await hive.openBox<String>(
        'test',
        compactionStrategy: const IsolatedCompactionStrategy.always(),
      );

      await _putEntries(box, 10);
      final sizeAfterPuts = await _fileSize(box);

      for (var i = 0; i < 5; i++) {
        await box.delete('key$i');
      }

      expect(await box.length, 5);
      expect(await _fileSize(box), lessThan(sizeAfterPuts));
    });
  });
}
