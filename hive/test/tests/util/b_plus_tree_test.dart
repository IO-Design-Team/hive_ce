import 'dart:collection';
import 'dart:math';

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

    test(
      'ascending inserts trigger tail fast path across multiple heights',
      () {
        final tree = BPlusTree<int, String>(_intCompare);
        // 63 * 63 + 531 = 4500 ensures height >= 3 on right-edge tail splits.
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
      },
    );

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

    test('sparse tail leaf borrow, merge, and root collapse edge cases', () {
      // Deleting the sole entry in a 1-entry tail leaf when left sibling has
      // > 32 entries borrows from left.
      final borrowTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 64; i++) {
        borrowTree.insert(i, i);
      }
      borrowTree.debugVerifyInvariants();
      expect(borrowTree.delete(63), 63);
      borrowTree.debugVerifyInvariants();
      expect(borrowTree.length, 63);

      // Deleting from child 0 down to < 32 entries when right sibling is a
      // 1-entry tail leaf merges and collapses root cleanly.
      final mergeTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 64; i++) {
        mergeTree.insert(i, i);
      }
      // Shrink left child (0..62) to 32 entries, leaving tail with [63].
      for (var i = 0; i < 31; i++) {
        expect(mergeTree.delete(i), i);
      }
      mergeTree.debugVerifyInvariants();
      // Now left child has 32 entries and tail has 1 entry; deleting 31 forces
      // left child to 31 and merges with the 1-entry tail, collapsing root.
      expect(mergeTree.delete(31), 31);
      mergeTree.debugVerifyInvariants();
      expect(mergeTree.length, 32);
      expect(mergeTree.keys, List.generate(32, (i) => i + 32));

      // Deleting the sole entry of a 1-entry tail when left sibling has 32
      // entries merges tail into left sibling and updates _tail.
      final tailMergeTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 64; i++) {
        tailMergeTree.insert(i, i);
      }
      for (var i = 0; i < 31; i++) {
        expect(tailMergeTree.delete(i), i);
      }
      tailMergeTree.debugVerifyInvariants();
      expect(tailMergeTree.delete(63), 63);
      tailMergeTree.debugVerifyInvariants();
      expect(tailMergeTree.length, 32);
      expect(tailMergeTree.insert(100, 100), null);
      tailMergeTree.debugVerifyInvariants();
      expect(tailMergeTree.getKeyAt(32), 100);
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
      expect(tree.delete(2), null);
      expect(tree.containsKey(2), false);
      tree.debugVerifyInvariants();
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
}
