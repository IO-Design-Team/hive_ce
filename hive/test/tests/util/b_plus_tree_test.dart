import 'dart:collection';
import 'dart:math';

import 'package:hive_ce/src/util/b_plus_tree.dart';
import 'package:test/test.dart';

const _capacity = 64;
const _maxEntries = 63;
const _minFill = 32;

int _intCompare(int a, int b) => a.compareTo(b);

int _reverseIntCompare(int a, int b) => b.compareTo(a);

void verifyInvariants<K>(
  BPlusTree<K, Object?> tree,
  Comparator<K> comparator,
) {
  final snapshot = tree.debugSnapshot();
  if (snapshot.length == 0) {
    if (snapshot.height != 1) {
      throw StateError('Empty tree must have height 1, got ${snapshot.height}');
    }
    if (!identical(snapshot.root, snapshot.head) ||
        !identical(snapshot.root, snapshot.tail)) {
      throw StateError('Empty tree root/head/tail mismatch');
    }
    final headInfo = snapshot.inspect(snapshot.head);
    if (!headInfo.isLeaf || headInfo.count != 0 || headInfo.next != null) {
      throw StateError('Empty root leaf is not clean');
    }
    final values = headInfo.values;
    for (var i = 0; i < _capacity; i++) {
      if (headInfo.keys[i] != null || (values != null && values[i] != null)) {
        throw StateError('Unclean empty root slot at $i');
      }
    }
    return;
  }

  final visitedLeaves = <Object>[];

  (int, K, K) verifySubtree(Object node, int depth) {
    final info = snapshot.inspect(node);
    if (!info.isLeaf) {
      if (depth >= snapshot.height) {
        throw StateError(
          'Internal node found at leaf depth $depth/${snapshot.height}',
        );
      }
      if (info.count < 2 || info.count > _maxEntries) {
        throw StateError(
          'Internal node count ${info.count} out of [2, $_maxEntries]',
        );
      }
      final children = info.children;
      final counts = info.counts;
      if (children == null || counts == null) {
        throw StateError('Internal node missing children or counts');
      }
      for (var i = info.count - 1; i < _capacity - 1; i++) {
        if (info.keys[i] != null) {
          throw StateError('Unclean separator key at $i');
        }
      }
      for (var i = info.count; i < _capacity; i++) {
        if (children[i] != null || counts[i] != 0) {
          throw StateError('Unclean child slot at $i');
        }
      }

      var total = 0;
      K? firstMin;
      K? prevMax;
      for (var i = 0; i < info.count; i++) {
        final child = children[i];
        if (child == null) {
          throw StateError('Null child at $i');
        }
        final (cCount, cMin, cMax) = verifySubtree(child, depth + 1);
        if (cCount != counts[i]) {
          throw StateError(
            'Subtree count mismatch at $i: ${counts[i]} != $cCount',
          );
        }
        final childInfo = snapshot.inspect(child);
        if (i > 0) {
          final prevChild = children[i - 1];
          if (prevChild == null) {
            throw StateError('Null child at ${i - 1}');
          }
          final prevInfo = snapshot.inspect(prevChild);
          final childIsTail =
              childInfo.isLeaf && identical(child, snapshot.tail);
          if (!childIsTail &&
              prevInfo.count < _minFill &&
              childInfo.count < _minFill) {
            throw StateError(
              'Adjacent underfilled non-tail siblings: '
              '${prevInfo.count}, ${childInfo.count}',
            );
          }
          final sep = info.keys[i - 1] as K;
          if (comparator(prevMax as K, sep) >= 0) {
            throw StateError('Left max $prevMax >= separator $sep');
          }
          if (comparator(sep, cMin) > 0) {
            throw StateError('Separator $sep > right min $cMin');
          }
        } else {
          firstMin = cMin;
        }
        total += cCount;
        prevMax = cMax;
      }
      return (total, firstMin as K, prevMax as K);
    }

    if (depth != snapshot.height) {
      throw StateError('Leaf depth $depth != height ${snapshot.height}');
    }
    if (info.count < 1 || info.count > _maxEntries) {
      throw StateError(
        'Leaf count ${info.count} out of [1, $_maxEntries]',
      );
    }
    final values = info.values;
    for (var i = info.count; i < _capacity; i++) {
      if (info.keys[i] != null || (values != null && values[i] != null)) {
        throw StateError('Unclean leaf slot at $i');
      }
    }
    visitedLeaves.add(node);
    return (info.count, info.keys[0] as K, info.keys[info.count - 1] as K);
  }

  final (total, _, _) = verifySubtree(snapshot.root, 1);
  if (total != snapshot.length) {
    throw StateError(
      'Length mismatch: tree has $total, length=${snapshot.length}',
    );
  }
  if (visitedLeaves.isEmpty ||
      !identical(visitedLeaves.first, snapshot.head) ||
      !identical(visitedLeaves.last, snapshot.tail)) {
    throw StateError('Head/tail pointers do not match tree edges');
  }

  Object? cursor = snapshot.head;
  var index = 0;
  var hasPrev = false;
  K? prevKey;
  while (cursor != null) {
    if (index >= visitedLeaves.length ||
        !identical(cursor, visitedLeaves[index])) {
      throw StateError('Leaf chain mismatch at leaf $index');
    }
    final info = snapshot.inspect(cursor);
    for (var i = 0; i < info.count; i++) {
      final key = info.keys[i] as K;
      if (hasPrev && comparator(prevKey as K, key) >= 0) {
        throw StateError('Out-of-order keys in leaves: $prevKey >= $key');
      }
      prevKey = key;
      hasPrev = true;
    }
    index++;
    final nextLeaf = info.next;
    if (nextLeaf == null) {
      if (!identical(cursor, snapshot.tail)) {
        throw StateError('Tail pointer does not match end of leaf chain');
      }
      break;
    }
    cursor = nextLeaf;
  }
  if (index != visitedLeaves.length) {
    throw StateError(
      'Visited ${visitedLeaves.length} leaves in tree, $index in chain',
    );
  }
}

void main() {
  group('BPlusTree', () {
    test('empty tree behavior', () {
      final tree = BPlusTree<int, String>(_intCompare);
      verifyInvariants(tree, _intCompare);
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
            verifyInvariants(tree, _intCompare);
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
          verifyInvariants(tree, _intCompare);
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
      verifyInvariants(tree, _intCompare);
      expect(tree.length, 300);
      for (var i = 0; i < 300; i++) {
        expect(tree.get(i), i % 3 == 0 ? 'b$i' : 'a$i');
      }
    });

    test('deletions down to zero (ascending, descending, and random)', () {
      const count = 4300;

      // Ascending deletion (exercises left-edge merges).
      final ascTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < count; i++) {
        ascTree.insert(i, i);
      }
      for (var i = 0; i < count; i++) {
        expect(ascTree.delete(i), i);
        expect(ascTree.delete(i), null);
        if (i < 150 || i > count - 150 || i % 250 == 0) {
          verifyInvariants(ascTree, _intCompare);
        }
      }
      expect(ascTree.length, 0);
      expect(ascTree.keys, isEmpty);

      // Descending deletion (exercises tail & left-neighbor merges).
      final descTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < count; i++) {
        descTree.insert(i, i);
      }
      for (var i = count - 1; i >= 0; i--) {
        expect(descTree.delete(i), i);
        if (i < 150 || i > count - 150 || i % 250 == 0) {
          verifyInvariants(descTree, _intCompare);
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
          verifyInvariants(randTree, _intCompare);
        }
      }
      expect(randTree.length, 0);
      expect(randTree.values, isEmpty);
    });

    test('sparse tail leaf merge and root collapse edge cases', () {
      // Deleting the sole entry in a 1-entry tail leaf when left sibling has
      // 63 entries merges into left and collapses the root.
      final singleTailTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 64; i++) {
        singleTailTree.insert(i, i);
      }
      verifyInvariants(singleTailTree, _intCompare);
      expect(singleTailTree.delete(63), 63);
      verifyInvariants(singleTailTree, _intCompare);
      expect(singleTailTree.length, 63);

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
      verifyInvariants(mergeTree, _intCompare);
      // Now left child has 32 entries and tail has 1 entry; deleting 31 forces
      // left child to 31 and merges with the 1-entry tail, collapsing root.
      expect(mergeTree.delete(31), 31);
      verifyInvariants(mergeTree, _intCompare);
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
      verifyInvariants(tailMergeTree, _intCompare);
      expect(tailMergeTree.delete(63), 63);
      verifyInvariants(tailMergeTree, _intCompare);
      expect(tailMergeTree.length, 32);
      expect(tailMergeTree.insert(100, 100), null);
      verifyInvariants(tailMergeTree, _intCompare);
      expect(tailMergeTree.getKeyAt(32), 100);
    });

    test('right-to-left sparse leaf merges including tail merge', () {
      // Sub-case A: merge right into _tail and update _tail.
      final tailTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 127; i++) {
        tailTree.insert(i, i);
      }
      for (var i = 125; i >= 94; i--) {
        expect(tailTree.delete(i), i);
      }
      verifyInvariants(tailTree, _intCompare);
      expect(tailTree.length, 95);
      expect(tailTree.keys.toList(), [...List.generate(94, (i) => i), 126]);
      expect(tailTree.insert(200, 200), null);
      verifyInvariants(tailTree, _intCompare);
      expect(tailTree.getKeyAt(tailTree.length - 1), 200);

      // Sub-case B: merge right into non-tail leaf, then empty child 0 into right.
      final tree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 190; i++) {
        tree.insert(i, i);
      }
      for (var i = 188; i >= 158; i--) {
        expect(tree.delete(i), i);
      }
      verifyInvariants(tree, _intCompare);
      for (var i = 125; i >= 94; i--) {
        expect(tree.delete(i), i);
      }
      verifyInvariants(tree, _intCompare);
      expect(
        tree.keys.toList(),
        [
          ...List.generate(94, (i) => i),
          ...List.generate(32, (i) => 126 + i),
          189,
        ],
      );

      for (var i = 62; i >= 0; i--) {
        expect(tree.delete(i), i);
      }
      verifyInvariants(tree, _intCompare);
      expect(
        tree.keys.toList(),
        [
          ...List.generate(31, (i) => 63 + i),
          ...List.generate(32, (i) => 126 + i),
          189,
        ],
      );
    });

    test('internal node 1-child redistribution with 63-child sibling', () {
      void expectRootChildCounts(
        BPlusTree<int, int> tree,
        int leftCount,
        int rightCount, {
        bool checkHeight = false,
      }) {
        final snap = tree.debugSnapshot();
        if (checkHeight) {
          expect(snap.height, 3);
        }
        final rootInfo = snap.inspect(snap.root);
        final children = rootInfo.children ?? fail('Expected root children');
        expect(rootInfo.count, 2);
        final c0 = children[0] ?? fail('Missing child 0');
        final c1 = children[1] ?? fail('Missing child 1');
        expect(snap.inspect(c0).count, leftCount);
        expect(snap.inspect(c1).count, rightCount);
        verifyInvariants(tree, _intCompare);
      }

      // Sub-case A: left 63-child sibling (childIdx == 1).
      final leftSibTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 3970; i++) {
        leftSibTree.insert(i * 100, i);
      }
      for (var j = 0; j < 31; j++) {
        leftSibTree.insert(j * 63 * 100 + 1, j);
      }
      expectRootChildCounts(leftSibTree, 63, 32, checkHeight: true);

      for (var i = 3969; i >= 34 * 63; i--) {
        expect(leftSibTree.delete(i * 100), i);
      }
      expectRootChildCounts(leftSibTree, 63, 2);

      for (var i = 33 * 63 + 62; i >= 33 * 63; i--) {
        expect(leftSibTree.delete(i * 100), i);
      }
      expectRootChildCounts(leftSibTree, 32, 32, checkHeight: true);
      expect(leftSibTree.length, 32 * 63 + 31 + 63);
      expect(leftSibTree.get(0), 0);
      expect(leftSibTree.get(32 * 63 * 100), 32 * 63);
      expect(leftSibTree.getAt(leftSibTree.length - 1), 33 * 63 - 1);

      // Sub-case B: right 63-child sibling (childIdx == 0).
      final rightSibTree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 3970; i++) {
        rightSibTree.insert(i * 100, i);
      }
      for (var j = 32; j < 63; j++) {
        rightSibTree.insert(j * 63 * 100 + 1, j);
      }
      expectRootChildCounts(rightSibTree, 32, 63, checkHeight: true);

      for (var i = 0; i < 30 * 63; i++) {
        expect(rightSibTree.delete(i * 100), i);
      }
      expectRootChildCounts(rightSibTree, 2, 63);

      for (var i = 30 * 63; i < 31 * 63; i++) {
        expect(rightSibTree.delete(i * 100), i);
      }
      expectRootChildCounts(rightSibTree, 32, 32, checkHeight: true);
      expect(rightSibTree.length, 3970 - 31 * 63 + 31);
      expect(rightSibTree.get(31 * 63 * 100), 31 * 63);
      expect(rightSibTree.get(3969 * 100), 3969);
      expect(rightSibTree.getAt(0), 31 * 63);
      expect(rightSibTree.getAt(rightSibTree.length - 1), 3969);
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
      verifyInvariants(tree, _reverseIntCompare);
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
      verifyInvariants(tree, _reverseIntCompare);
    });

    test('clear and reuse', () {
      final tree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 300; i++) {
        tree.insert(i, i);
      }
      tree.clear();
      verifyInvariants(tree, _intCompare);
      expect(tree.length, 0);
      expect(tree.keys, isEmpty);
      expect(tree.values, isEmpty);
      expect(tree.get(0), null);
      expect(() => tree.getAt(0), throwsRangeError);

      for (var i = 500; i < 650; i++) {
        tree.insert(i, i * 10);
      }
      verifyInvariants(tree, _intCompare);
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
          verifyInvariants(tree, _intCompare);
          expect(tree.keys.toList(), ref.keys.toList());
          expect(tree.values.toList(), ref.values.toList());
        }
      }
    });
  });
}
