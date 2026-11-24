@TestOn('vm')
library;

import 'dart:collection';
import 'dart:math';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import '../tests/common.dart';

void main() {
  group('BPlusTree Hive persistence', () {
    List<dynamic> buildKeyPool() => <dynamic>[
          for (var i = 0; i < 650; i++) i * 50,
          0,
          1,
          50000,
          '',
          '0',
          '🔑',
          '日本語',
          'long_${'x' * 240}',
          for (var i = 0; i < 650; i++) 'str_${i.toString().padLeft(4, '0')}',
        ];

    List<dynamic> expectedValuesBetween(
      SplayTreeMap<dynamic, dynamic> ref, {
      dynamic startKey,
      dynamic endKey,
    }) {
      if (startKey != null && !ref.containsKey(startKey)) {
        return const [];
      }
      final result = <dynamic>[];
      var started = startKey == null;
      for (final entry in ref.entries) {
        if (!started) {
          if (defaultKeyComparator(entry.key, startKey) != 0) continue;
          started = true;
        }
        result.add(entry.value);
        if (endKey != null && defaultKeyComparator(entry.key, endKey) == 0) {
          break;
        }
      }
      return result;
    }

    void verifyEagerBox(Box<dynamic> box, SplayTreeMap<dynamic, dynamic> ref) {
      expect(box.length, ref.length);
      expect(box.keys.toList(), ref.keys.toList());
      expect(box.values.toList(), ref.values.toList());
      expect(box.toMap(), Map<dynamic, dynamic>.from(ref));

      for (final entry in ref.entries) {
        expect(box.containsKey(entry.key), true);
        expect(box.get(entry.key), entry.value);
      }

      if (ref.isNotEmpty) {
        final keysList = ref.keys.toList();
        for (final idx in [0, keysList.length ~/ 2, keysList.length - 1]) {
          final k = keysList[idx];
          expect(box.keyAt(idx), k);
          expect(box.getAt(idx), ref[k]);
        }

        final start = keysList[keysList.length ~/ 4];
        final end = keysList[(keysList.length * 3) ~/ 4];
        expect(
          box.valuesBetween(startKey: start, endKey: end).toList(),
          expectedValuesBetween(ref, startKey: start, endKey: end),
        );
        expect(
          box.valuesBetween(startKey: start).toList(),
          expectedValuesBetween(ref, startKey: start),
        );
        expect(
          box.valuesBetween(endKey: end).toList(),
          expectedValuesBetween(ref, endKey: end),
        );
        expect(box.valuesBetween(startKey: '__missing_key__'), isEmpty);
      }
    }

    Future<void> verifyLazyBox(
      LazyBox<dynamic> box,
      SplayTreeMap<dynamic, dynamic> ref,
    ) async {
      expect(box.length, ref.length);
      expect(box.keys.toList(), ref.keys.toList());

      for (final entry in ref.entries) {
        expect(box.containsKey(entry.key), true);
        expect(await box.get(entry.key), entry.value);
      }

      if (ref.isNotEmpty) {
        final keysList = ref.keys.toList();
        for (final idx in [0, keysList.length ~/ 2, keysList.length - 1]) {
          final k = keysList[idx];
          expect(box.keyAt(idx), k);
          expect(await box.getAt(idx), ref[k]);
        }
      }
    }

    test('eager Box fuzz with compaction, close/reopen, and clear', () async {
      final dir = await getTempDir();
      final hive = HiveImpl()..init(dir.path);
      addTearDown(hive.close);

      final boxName = generateBoxName();
      var box = await hive.openBox<dynamic>(
        boxName,
        compactionStrategy: (entries, deletedEntries) => false,
        crashRecovery: false,
      );

      final ref = SplayTreeMap<dynamic, dynamic>(defaultKeyComparator);
      final keyPool = buildKeyPool();
      final rng = Random(41401);

      // Grow past 1,050 live keys first so the B+ tree spans multiple levels.
      for (var i = 0; i < keyPool.length; i++) {
        final k = keyPool[i];
        final v = 'init_$i';
        await box.put(k, v);
        ref[k] = v;
      }
      expect(box.length, greaterThan(1000));
      verifyEagerBox(box, ref);

      // Mixed ops with periodic compact and close/reopen checkpoints.
      for (var step = 0; step < 600; step++) {
        final op = rng.nextInt(100);
        if (op < 35) {
          final k = keyPool[rng.nextInt(keyPool.length)];
          final v = 'put_$step';
          await box.put(k, v);
          ref[k] = v;
        } else if (op < 48) {
          final batch = <dynamic, dynamic>{};
          for (var j = 0; j < 4; j++) {
            final k = keyPool[rng.nextInt(keyPool.length)];
            batch[k] = 'putAll_${step}_$j';
          }
          await box.putAll(batch);
          ref.addAll(batch);
        } else if (op < 56 && ref.isNotEmpty) {
          final idx = rng.nextInt(ref.length);
          final k = ref.keys.elementAt(idx);
          final v = 'putAt_$step';
          await box.putAt(idx, v);
          ref[k] = v;
        } else if (op < 63) {
          final v = 'add_$step';
          final k = await box.add(v);
          ref[k] = v;
        } else if (op < 68) {
          final vals = ['addAll_${step}_0', 'addAll_${step}_1'];
          final keys = (await box.addAll(vals)).toList();
          for (var j = 0; j < keys.length; j++) {
            ref[keys[j]] = vals[j];
          }
        } else if (op < 84) {
          final k = keyPool[rng.nextInt(keyPool.length)];
          await box.delete(k);
          ref.remove(k);
        } else if (op < 92) {
          final delKeys = [
            for (var j = 0; j < 3; j++) keyPool[rng.nextInt(keyPool.length)],
          ];
          await box.deleteAll(delKeys);
          for (final k in delKeys) {
            ref.remove(k);
          }
        } else if (ref.isNotEmpty) {
          final idx = rng.nextInt(ref.length);
          final k = ref.keys.elementAt(idx);
          await box.deleteAt(idx);
          ref.remove(k);
        }

        if (step == 199 || step == 399 || step == 599) {
          verifyEagerBox(box, ref);
          await box.compact();
          verifyEagerBox(box, ref);

          await box.close();
          box = await hive.openBox<dynamic>(
            boxName,
            compactionStrategy: (entries, deletedEntries) => false,
            crashRecovery: false,
          );
          verifyEagerBox(box, ref);
        }
      }

      // Clear and regrow across splits, then compact and reopen.
      await box.clear();
      ref.clear();
      verifyEagerBox(box, ref);

      for (var i = 0; i < 400; i++) {
        final k = keyPool[i];
        final v = 'regrow_$i';
        await box.put(k, v);
        ref[k] = v;
      }
      await box.compact();
      verifyEagerBox(box, ref);

      await box.close();
      box = await hive.openBox<dynamic>(
        boxName,
        compactionStrategy: (entries, deletedEntries) => false,
        crashRecovery: false,
      );
      verifyEagerBox(box, ref);
    });

    test('LazyBox fuzz with compaction, close/reopen, and clear', () async {
      final dir = await getTempDir();
      final hive = HiveImpl()..init(dir.path);
      addTearDown(hive.close);

      final boxName = generateBoxName();
      var box = await hive.openLazyBox<dynamic>(
        boxName,
        compactionStrategy: (entries, deletedEntries) => false,
        crashRecovery: false,
      );

      final ref = SplayTreeMap<dynamic, dynamic>(defaultKeyComparator);
      final keyPool = buildKeyPool();
      final rng = Random(41402);

      for (var i = 0; i < keyPool.length; i++) {
        final k = keyPool[i];
        final v = 'lazy_init_$i';
        await box.put(k, v);
        ref[k] = v;
      }
      expect(box.length, greaterThan(1000));
      await verifyLazyBox(box, ref);

      for (var step = 0; step < 600; step++) {
        final op = rng.nextInt(100);
        if (op < 35) {
          final k = keyPool[rng.nextInt(keyPool.length)];
          final v = 'lazy_put_$step';
          await box.put(k, v);
          ref[k] = v;
        } else if (op < 48) {
          final batch = <dynamic, dynamic>{};
          for (var j = 0; j < 4; j++) {
            final k = keyPool[rng.nextInt(keyPool.length)];
            batch[k] = 'lazy_putAll_${step}_$j';
          }
          await box.putAll(batch);
          ref.addAll(batch);
        } else if (op < 56 && ref.isNotEmpty) {
          final idx = rng.nextInt(ref.length);
          final k = ref.keys.elementAt(idx);
          final v = 'lazy_putAt_$step';
          await box.putAt(idx, v);
          ref[k] = v;
        } else if (op < 63) {
          final v = 'lazy_add_$step';
          final k = await box.add(v);
          ref[k] = v;
        } else if (op < 68) {
          final vals = ['lazy_addAll_${step}_0', 'lazy_addAll_${step}_1'];
          final keys = (await box.addAll(vals)).toList();
          for (var j = 0; j < keys.length; j++) {
            ref[keys[j]] = vals[j];
          }
        } else if (op < 84) {
          final k = keyPool[rng.nextInt(keyPool.length)];
          await box.delete(k);
          ref.remove(k);
        } else if (op < 92) {
          final delKeys = [
            for (var j = 0; j < 3; j++) keyPool[rng.nextInt(keyPool.length)],
          ];
          await box.deleteAll(delKeys);
          for (final k in delKeys) {
            ref.remove(k);
          }
        } else if (ref.isNotEmpty) {
          final idx = rng.nextInt(ref.length);
          final k = ref.keys.elementAt(idx);
          await box.deleteAt(idx);
          ref.remove(k);
        }

        if (step == 199 || step == 399 || step == 599) {
          await verifyLazyBox(box, ref);
          await box.compact();
          await verifyLazyBox(box, ref);

          await box.close();
          box = await hive.openLazyBox<dynamic>(
            boxName,
            compactionStrategy: (entries, deletedEntries) => false,
            crashRecovery: false,
          );
          await verifyLazyBox(box, ref);
        }
      }

      await box.clear();
      ref.clear();
      await verifyLazyBox(box, ref);

      for (var i = 0; i < 400; i++) {
        final k = keyPool[i];
        final v = 'lazy_regrow_$i';
        await box.put(k, v);
        ref[k] = v;
      }
      await box.compact();
      await verifyLazyBox(box, ref);

      await box.close();
      box = await hive.openLazyBox<dynamic>(
        boxName,
        compactionStrategy: (entries, deletedEntries) => false,
        crashRecovery: false,
      );
      await verifyLazyBox(box, ref);
    });

    test('custom reverse keyComparator box compact and reopen', () async {
      int reverseComparator(dynamic a, dynamic b) => defaultKeyComparator(b, a);

      final dir = await getTempDir();
      final hive = HiveImpl()..init(dir.path);
      addTearDown(hive.close);

      final boxName = generateBoxName();
      var box = await hive.openBox<int>(
        boxName,
        keyComparator: reverseComparator,
        compactionStrategy: (entries, deletedEntries) => false,
        crashRecovery: false,
      );

      final ref = SplayTreeMap<dynamic, int>(reverseComparator);
      for (var i = 0; i < 400; i++) {
        await box.put(i, i * 10);
        ref[i] = i * 10;
      }
      for (var i = 0; i < 400; i += 3) {
        await box.put(i, i * 20);
        ref[i] = i * 20;
      }
      for (var i = 1; i < 400; i += 4) {
        await box.delete(i);
        ref.remove(i);
      }

      expect(box.length, ref.length);
      expect(box.keys.toList(), ref.keys.toList());
      expect(box.values.toList(), ref.values.toList());

      await box.compact();
      expect(box.keys.toList(), ref.keys.toList());
      expect(box.values.toList(), ref.values.toList());

      await box.close();
      box = await hive.openBox<int>(
        boxName,
        keyComparator: reverseComparator,
        compactionStrategy: (entries, deletedEntries) => false,
        crashRecovery: false,
      );
      expect(box.length, ref.length);
      expect(box.keys.toList(), ref.keys.toList());
      expect(box.values.toList(), ref.values.toList());
      for (final entry in ref.entries) {
        expect(box.get(entry.key), entry.value);
      }
      expect(expectNotNull(box.path), isNotEmpty);
    });
  });
}
