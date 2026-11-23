@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import '../tests/common.dart';

Future<BoxBase<dynamic>> _openBox(
  HiveImpl hive,
  String name, {
  required bool lazy,
}) {
  if (lazy) {
    return hive.openLazyBox<dynamic>(
      name,
      compactionStrategy: (entries, deletedEntries) => false,
      crashRecovery: false,
    );
  }
  return hive.openBox<dynamic>(
    name,
    compactionStrategy: (entries, deletedEntries) => false,
    crashRecovery: false,
  );
}

Future<dynamic> _getValue(BoxBase<dynamic> box, dynamic key) async {
  if (box is LazyBox<dynamic>) {
    return await box.get(key);
  }
  return (box as Box<dynamic>).get(key);
}

void main() {
  group('compaction', () {
    for (final lazy in [false, true]) {
      final label = lazy ? 'lazy box' : 'normal box';

      test(
        'compacts $label with large deleted gaps and preserves live frames',
        () async {
          final dir = await getTempDir();
          final hive = HiveImpl()..init(dir.path);
          addTearDown(hive.close);

          final boxName = generateBoxName();
          var box = await _openBox(hive, boxName, lazy: lazy);

          final largeLive = Uint8List.fromList(
            List.generate(100 * 1024, (i) => i & 0xff),
          );
          final deadPayload = Uint8List(128 * 1024);

          await box.put('start', 'first');
          await box.put('small_dead', 'x' * 100);
          await box.put('after_small_gap', 'second');
          for (var i = 0; i < 4; i++) {
            await box.put('large_dead_$i', deadPayload);
          }
          await box.put('after_large_gap', 'third');
          await box.put('large_live', largeLive);
          await box.put('large_dead_4', deadPayload);
          for (var i = 0; i < 200; i++) {
            await box.put('scattered_$i', 'value_$i');
          }

          await box.delete('small_dead');
          for (var i = 0; i < 5; i++) {
            await box.delete('large_dead_$i');
          }

          final file = File(expectNotNull(box.path));
          final sizeBefore = await file.length();

          await box.compact();

          final sizeAfter = await file.length();
          expect(sizeAfter, lessThan(sizeBefore - 500 * 1024));

          Future<void> verifyContents(BoxBase<dynamic> currentBox) async {
            expect(await _getValue(currentBox, 'start'), 'first');
            expect(await _getValue(currentBox, 'after_small_gap'), 'second');
            expect(await _getValue(currentBox, 'after_large_gap'), 'third');
            expect(await _getValue(currentBox, 'large_live'), largeLive);
            for (var i = 0; i < 200; i++) {
              expect(await _getValue(currentBox, 'scattered_$i'), 'value_$i');
            }
            expect(currentBox.containsKey('small_dead'), false);
            for (var i = 0; i < 5; i++) {
              expect(currentBox.containsKey('large_dead_$i'), false);
            }
          }

          await verifyContents(box);

          await box.close();
          box = await _openBox(hive, boxName, lazy: lazy);
          await verifyContents(box);

          await box.put('post_compact', 'works');
          await box.close();
          box = await _openBox(hive, boxName, lazy: lazy);
          expect(await _getValue(box, 'post_compact'), 'works');
          expect(await _getValue(box, 'after_large_gap'), 'third');
        },
      );
    }

    test(
      'throws Unexpected EOF when live frame after deleted gap is truncated',
      () async {
        final dir = await getTempDir();
        final hive = HiveImpl()..init(dir.path);
        addTearDown(hive.close);

        final box = await _openBox(hive, generateBoxName(), lazy: false);
        await box.put('a', 'first');
        await box.put('dead', Uint8List(128 * 1024));
        await box.delete('dead');
        await box.put('b', 'last');

        final file = File(expectNotNull(box.path));
        final length = await file.length();
        final raf = await file.open(mode: FileMode.writeOnlyAppend);
        try {
          await raf.truncate(length - 1);
        } finally {
          await raf.close();
        }

        await expectLater(box.compact, throwsHiveError(['unexpected eof']));
      },
    );

    test(
      'throws Unexpected EOF when deleted gap seek target is past EOF',
      () async {
        final dir = await getTempDir();
        final hive = HiveImpl()..init(dir.path);
        addTearDown(hive.close);

        final box = await _openBox(hive, generateBoxName(), lazy: false);
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
