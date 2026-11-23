import 'dart:collection';
import 'dart:math';

import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/util/b_plus_tree.dart';
import 'package:test/test.dart';

int _intCompare(int a, int b) => a.compareTo(b);

int _reverseIntCompare(int a, int b) => b.compareTo(a);

void main() {
  group('BPlusTree', () {
    test('empty tree behavior', () {
      final tree = BPlusTree<int, String>(_intCompare);
      tree.debugVerifyInvariants();
      expect(tree.length, 0);
      expect(tree.isEmpty, true);
      expect(tree.isNotEmpty, false);
      expect(tree.keys, isEmpty);
      expect(tree.values, isEmpty);
      expect(tree.get(1), null);
      expect(tree.containsKey(1), false);
      expect(tree.delete(1), null);
      expect(tree.valuesFromKey(1), isEmpty);
      expect(() => tree.getAt(0), throwsRangeError);
      expect(() => tree.getAt(-1), throwsRangeError);
      expect(() => tree.getKeyAt(0), throwsRangeError);
      expect(() => tree.getKeyAt(-1), throwsRangeError);
    });

    test('ascending inserts trigger tail fast path across multiple heights',
        () {
      final tree = BPlusTree<int, String>(_intCompare);
      // 64 * 64 + 200 = 4296 ensures height >= 3 on right-edge tail splits.
      const count = 4500;
      for (var i = 0; i < count; i++) {
        expect(tree.insert(i, 'v$i'), null);
        if (i < 300 || i % 250 == 0 || i == count - 1) {
          tree.debugVerifyInvariants();
        }
      }

      expect(tree.length, count);
      expect(tree.isEmpty, false);
      expect(tree.isNotEmpty, true);
      expect(tree.keys.length, count);
      expect(tree.values.length, count);

      for (var i = 0; i < count; i++) {
        expect(tree.containsKey(i), true);
        expect(tree.get(i), 'v$i');
        expect(tree.getAt(i), 'v$i');
        expect(tree.getKeyAt(i), i);
      }
      expect(tree.containsKey(-1), false);
      expect(tree.containsKey(count), false);
      expect(() => tree.getAt(count), throwsRangeError);
      expect(() => tree.getKeyAt(count), throwsRangeError);
    });

    test('descending inserts across multiple heights', () {
      final tree = BPlusTree<int, int>(_intCompare);
      const count = 4500;
      for (var i = count - 1; i >= 0; i--) {
        expect(tree.insert(i, i * 2), null);
        if (i > count - 300 || i % 250 == 0 || i == 0) {
          tree.debugVerifyInvariants();
        }
      }

      expect(tree.length, count);
      expect(tree.keys, List.generate(count, (i) => i));
      for (var i = 0; i < count; i++) {
        expect(tree.get(i), i * 2);
        expect(tree.getAt(i), i * 2);
        expect(tree.getKeyAt(i), i);
      }
    });

    test('overwrites preserve length and return previous value', () {
      final tree = BPlusTree<int, String>(_intCompare);
      for (var i = 0; i < 300; i++) {
        expect(tree.insert(i, 'a$i'), null);
      }
      for (var i = 0; i < 300; i += 3) {
        expect(tree.insert(i, 'b$i'), 'a$i');
      }
      tree.debugVerifyInvariants();
      expect(tree.length, 300);
      for (var i = 0; i < 300; i++) {
        expect(tree.get(i), i % 3 == 0 ? 'b$i' : 'a$i');
      }
    });

    test('deletions down to zero (ascending, descending, and random)', () {
      const count = 4300;

      // Ascending deletion (exercises left-edge borrowFromRight & merge).
      final ascTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < count; i++) {
        ascTree.insert(i, i);
      }
      for (var i = 0; i < count; i++) {
        expect(ascTree.delete(i), i);
        expect(ascTree.delete(i), null);
        if (i < 150 || i > count - 150 || i % 250 == 0) {
          ascTree.debugVerifyInvariants();
        }
      }
      expect(ascTree.length, 0);
      expect(ascTree.keys, isEmpty);

      // Descending deletion (exercises tail & borrowFromLeft & merge).
      final descTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < count; i++) {
        descTree.insert(i, i);
      }
      for (var i = count - 1; i >= 0; i--) {
        expect(descTree.delete(i), i);
        if (i < 150 || i > count - 150 || i % 250 == 0) {
          descTree.debugVerifyInvariants();
        }
      }
      expect(descTree.length, 0);

      // Random deletion.
      final randTree = BPlusTree<int, int>(_intCompare);
      final keys = List.generate(count, (i) => i)..shuffle(Random(42));
      for (final k in keys) {
        randTree.insert(k, k);
      }
      keys.shuffle(Random(99));
      for (var i = 0; i < keys.length; i++) {
        final k = keys[i];
        expect(randTree.delete(k), k);
        if (i % 250 == 0 || i > keys.length - 100) {
          randTree.debugVerifyInvariants();
        }
      }
      expect(randTree.length, 0);
      expect(randTree.values, isEmpty);
    });

    test('valuesFromKey across leaf boundaries and missing keys', () {
      final tree = BPlusTree<int, String>(_intCompare);
      for (var i = 0; i < 200; i += 2) {
        tree.insert(i, 'v$i');
      }

      // Missing key returns empty iterable.
      expect(tree.valuesFromKey(1), isEmpty);
      expect(tree.valuesFromKey(-5), isEmpty);
      expect(tree.valuesFromKey(999), isEmpty);

      // Existing key iterates through end, and iterable can be iterated twice.
      final slice = tree.valuesFromKey(120);
      final expected = [for (var i = 120; i < 200; i += 2) 'v$i'];
      expect(slice, expected);
      expect(slice, expected);

      // Last key.
      expect(tree.valuesFromKey(198), ['v198']);

      // First key.
      expect(
        tree.valuesFromKey(0),
        [for (var i = 0; i < 200; i += 2) 'v$i'],
      );
    });

    test('custom comparator and nullable values', () {
      final tree = BPlusTree<int, String?>(_reverseIntCompare);
      for (var i = 0; i < 100; i++) {
        tree.insert(i, i.isEven ? null : 'v$i');
      }
      tree.debugVerifyInvariants();
      expect(tree.keys, List.generate(100, (i) => 99 - i));
      for (var i = 0; i < 100; i++) {
        expect(tree.containsKey(i), true);
        expect(tree.get(i), i.isEven ? null : 'v$i');
      }
      expect(tree.getAt(0), 'v99');
      expect(tree.getAt(1), null);
      expect(tree.getKeyAt(0), 99);
      expect(tree.valuesFromKey(2).toList(), [null, 'v1', null]);
    });

    test('clear and reuse', () {
      final tree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 300; i++) {
        tree.insert(i, i);
      }
      tree.clear();
      tree.debugVerifyInvariants();
      expect(tree.length, 0);
      expect(tree.keys, isEmpty);
      expect(tree.values, isEmpty);
      expect(tree.get(0), null);
      expect(() => tree.getAt(0), throwsRangeError);

      for (var i = 500; i < 650; i++) {
        tree.insert(i, i * 10);
      }
      tree.debugVerifyInvariants();
      expect(tree.length, 150);
      expect(tree.get(550), 5500);
      expect(tree.getAt(50), 5500);
    });

    test('iterator throws StateError before moveNext and after completion', () {
      final empty = BPlusTree<int, int>(_intCompare);
      final emptyKeyIt = empty.keys.iterator;
      expect(() => emptyKeyIt.current, throwsStateError);
      expect(emptyKeyIt.moveNext(), false);
      expect(() => emptyKeyIt.current, throwsStateError);

      final tree = BPlusTree<int, int>(_intCompare)..insert(1, 10);
      final valIt = tree.values.iterator;
      expect(() => valIt.current, throwsStateError);
      expect(valIt.moveNext(), true);
      expect(valIt.current, 10);
      expect(valIt.moveNext(), false);
      expect(() => valIt.current, throwsStateError);
    });

    test('differential stress test against SplayTreeMap (8000 ops)', () {
      final tree = BPlusTree<int, int>(_intCompare);
      final ref = SplayTreeMap<int, int>(_intCompare);
      final rng = Random(12345);
      var tailSeq = 100000;

      for (var step = 0; step < 8000; step++) {
        final op = rng.nextInt(100);
        if (op < 15) {
          // Ascending tail insert.
          final key = tailSeq++;
          final val = rng.nextInt(100000);
          final expected = ref[key];
          ref[key] = val;
          expect(tree.insert(key, val), expected);
        } else if (op < 60) {
          // Random insert / overwrite.
          final key = rng.nextInt(3000);
          final val = rng.nextInt(100000);
          final expected = ref[key];
          ref[key] = val;
          expect(tree.insert(key, val), expected);
        } else if (op < 90) {
          // Delete.
          final key = rng.nextInt(3000);
          final expected = ref.remove(key);
          expect(tree.delete(key), expected);
        } else if (op < 95 && ref.isNotEmpty) {
          // Point & index lookups.
          final idx = rng.nextInt(ref.length);
          final expectedKey = ref.keys.elementAt(idx);
          expect(tree.getKeyAt(idx), expectedKey);
          expect(tree.getAt(idx), ref[expectedKey]);
          expect(tree.get(expectedKey), ref[expectedKey]);
        } else {
          // Missing lookup.
          final key = 50000 + rng.nextInt(1000);
          expect(tree.containsKey(key), false);
          expect(tree.get(key), null);
        }

        expect(tree.length, ref.length);
        if (step % 400 == 0 || step == 7999) {
          tree.debugVerifyInvariants();
          expect(tree.keys.toList(), ref.keys.toList());
          expect(tree.values.toList(), ref.values.toList());
        }
      }
    });
  });

  group('PackedLazyBPlusTree', () {
    test('stores and reconstructs offsets (53-bit safe) and nullable lengths',
        () {
      final tree = PackedLazyBPlusTree<dynamic>(defaultKeyComparator);
      tree.debugVerifyInvariants();

      // 1099511627776 == 2^40 (written as literal for dart2js safety).
      expect(tree.insertLazy('a', 1099511627776, 128), null);
      expect(tree.insertLazy(10, 0, null), null);
      expect(tree.insertLazy('b', -1, null), null);
      tree.debugVerifyInvariants();

      expect(tree.length, 3);
      final f0 = tree.getAt(0);
      expect(f0.key, 10);
      expect(f0.lazy, true);
      expect(f0.offset, 0);
      expect(f0.length, null);

      final f1 = tree.get('a')!;
      expect(f1.key, 'a');
      expect(f1.lazy, true);
      expect(f1.offset, 1099511627776);
      expect(f1.length, 128);

      final f2 = tree.getAt(2);
      expect(f2.key, 'b');
      expect(f2.offset, -1);
      expect(f2.length, null);

      // Overwrite returns previous Frame.lazy.
      final old = tree.insertLazy('a', 2048, 64)!;
      expect(old.key, 'a');
      expect(old.offset, 1099511627776);
      expect(old.length, 128);
      expect(tree.get('a')!.offset, 2048);
      expect(tree.get('a')!.length, 64);

      // updateOffsetAndLength updates existing and ignores missing keys.
      tree.updateOffsetAndLength('a', 999999999999, 512);
      tree.updateOffsetAndLength('missing', 123, 45);
      expect(tree.length, 3);
      expect(tree.get('a')!.offset, 999999999999);
      expect(tree.get('a')!.length, 512);

      // frames and framesFromKey.
      expect(
        tree.frames.map((f) => (f.key, f.offset, f.length)).toList(),
        [
          (10, 0, null),
          ('a', 999999999999, 512),
          ('b', -1, null),
        ],
      );
      expect(
        tree
            .framesFromKey('a')
            .map((f) => (f.key, f.offset, f.length))
            .toList(),
        [
          ('a', 999999999999, 512),
          ('b', -1, null),
        ],
      );
      expect(tree.framesFromKey('nonexistent'), isEmpty);

      // deleteLazy returns removed Frame.lazy.
      final deleted = tree.deleteLazy('a')!;
      expect(deleted.key, 'a');
      expect(deleted.offset, 999999999999);
      expect(deleted.length, 512);
      expect(tree.deleteLazy('a'), null);
      tree.debugVerifyInvariants();

      tree.clear();
      tree.debugVerifyInvariants();
      expect(tree.length, 0);
      expect(tree.frames, isEmpty);
    });

    test('differential stress test against SplayTreeMap (5000 ops)', () {
      final tree = PackedLazyBPlusTree<dynamic>(defaultKeyComparator);
      final ref = SplayTreeMap<dynamic, Frame>(defaultKeyComparator);
      final rng = Random(67890);
      var tailSeq = 50000;

      for (var step = 0; step < 5000; step++) {
        final op = rng.nextInt(100);
        if (op < 15) {
          final key = tailSeq++;
          final offset = step * 64 + 1;
          final len = step % 7 == 0 ? null : (step % 500) + 16;
          final expected = ref[key];
          ref[key] = Frame.lazy(key, offset: offset, length: len);
          final prev = tree.insertLazy(key, offset, len);
          expect(prev?.offset, expected?.offset);
          expect(prev?.length, expected?.length);
        } else if (op < 55) {
          final key = rng.nextInt(2500);
          final offset = rng.nextInt(100000000);
          final len = rng.nextInt(5) == 0 ? null : rng.nextInt(4096) + 8;
          final expected = ref[key];
          ref[key] = Frame.lazy(key, offset: offset, length: len);
          final prev = tree.insertLazy(key, offset, len);
          expect(prev?.key, expected?.key);
          expect(prev?.offset, expected?.offset);
          expect(prev?.length, expected?.length);
        } else if (op < 80) {
          final key = rng.nextInt(2500);
          final expected = ref.remove(key);
          final removed = tree.deleteLazy(key);
          expect(removed?.key, expected?.key);
          expect(removed?.offset, expected?.offset);
          expect(removed?.length, expected?.length);
        } else if (op < 92 && ref.isNotEmpty) {
          final idx = rng.nextInt(ref.length);
          final key = ref.keys.elementAt(idx);
          final newOffset = rng.nextInt(100000000);
          final newLen = ref[key]!.length;
          ref[key] = Frame.lazy(key, offset: newOffset, length: newLen);
          tree.updateOffsetAndLength(key, newOffset, newLen);
          final actual = tree.getAt(idx);
          expect(actual.key, key);
          expect(actual.offset, newOffset);
          expect(actual.length, newLen);
        } else if (ref.isNotEmpty) {
          final idx = rng.nextInt(ref.length);
          final key = ref.keys.elementAt(idx);
          final actual = tree.get(key)!;
          final expected = ref[key]!;
          expect(actual.offset, expected.offset);
          expect(actual.length, expected.length);
        }

        expect(tree.length, ref.length);
        if (step % 400 == 0 || step == 4999) {
          tree.debugVerifyInvariants();
          final actualFrames = tree.frames.toList();
          final expectedFrames = ref.values.toList();
          expect(actualFrames.length, expectedFrames.length);
          for (var i = 0; i < expectedFrames.length; i++) {
            expect(actualFrames[i].key, expectedFrames[i].key);
            expect(actualFrames[i].offset, expectedFrames[i].offset);
            expect(actualFrames[i].length, expectedFrames[i].length);
          }
        }
      }
    });
  });
}
