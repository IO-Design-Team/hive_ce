@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import '../tests/common.dart';

void main() {
  group('compaction', () {
    test('compacts across a deleted gap larger than the read buffer', () async {
      final dir = await getTempDir();
      final hive = HiveImpl()..init(dir.path);
      addTearDown(hive.close);

      final boxName = generateBoxName();
      var box = await hive.openBox<dynamic>(
        boxName,
        compactionStrategy: (entries, deletedEntries) => false,
        crashRecovery: false,
      );

      final largeLive = Uint8List.fromList(
        List.generate(100 * 1024, (i) => i & 0xff),
      );

      await box.put('start', 'first');
      await box.put('small_dead', 'x' * 100);
      await box.put('after_small_gap', 'second');
      await box.put('large_dead', Uint8List(128 * 1024));
      await box.put('after_large_gap', 'third');
      await box.put('large_live', largeLive);
      for (var i = 0; i < 3; i++) {
        await box.put('scattered_$i', 'value_$i');
      }

      await box.delete('small_dead');
      await box.delete('large_dead');

      final file = File(expectNotNull(box.path));
      final sizeBefore = await file.length();

      await box.compact();

      expect(await file.length(), lessThan(sizeBefore - 100 * 1024));

      void verifyContents() {
        expect(box.get('start'), 'first');
        expect(box.get('after_small_gap'), 'second');
        expect(box.get('after_large_gap'), 'third');
        expect(box.get('large_live'), largeLive);
        for (var i = 0; i < 3; i++) {
          expect(box.get('scattered_$i'), 'value_$i');
        }
        expect(box.containsKey('small_dead'), false);
        expect(box.containsKey('large_dead'), false);
      }

      verifyContents();

      await box.close();
      box = await hive.openBox<dynamic>(
        boxName,
        compactionStrategy: (entries, deletedEntries) => false,
        crashRecovery: false,
      );
      verifyContents();
    });

    test(
      'throws Unexpected EOF when a deleted gap seek target is past EOF',
      () async {
        final dir = await getTempDir();
        final hive = HiveImpl()..init(dir.path);
        addTearDown(hive.close);

        final box = await hive.openBox<dynamic>(
          generateBoxName(),
          compactionStrategy: (entries, deletedEntries) => false,
          crashRecovery: false,
        );
        await box.put('a', 'first');
        await box.put('dead', Uint8List(128 * 1024));
        await box.delete('dead');
        await box.put('b', 'last');

        final file = File(expectNotNull(box.path));
        final raf = await file.open(mode: FileMode.writeOnlyAppend);
        try {
          await raf.truncate(64 * 1024);
        } finally {
          await raf.close();
        }

        await expectLater(box.compact, throwsHiveError(['unexpected eof']));
      },
    );
  });
}
