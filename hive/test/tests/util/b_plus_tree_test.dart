import 'dart:collection';
import 'dart:math';

import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/util/b_plus_tree.dart';
import 'package:test/test.dart';

const _capacity = 64;
const _maxEntries = 63;
const _minFill = 32;
const _maxHeight = 16;

int _intCompare(int a, int b) => a.compareTo(b);

int _reverseIntCompare(int a, int b) => b.compareTo(a);

int _nullableIntCompare(int? a, int? b) {
  if (a == null) return b == null ? 0 : -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

void verifyInvariants<K>(
  BPlusTree<K, Object?> tree,
  Comparator<K> comparator,
) {
  final snapshot = tree.debugSnapshot();
  if (snapshot.pathNodes.length != _maxHeight) {
    throw StateError(
      'Expected $_maxHeight pathNodes slots, got ${snapshot.pathNodes.length}',
    );
  }
  for (var i = 0; i < snapshot.pathNodes.length; i++) {
    if (snapshot.pathNodes[i] != null) {
      throw StateError('Unclean _pathNodes[$i]');
    }
  }

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
      final minChildren = depth == 1 ? 2 : _minFill;
      if (info.count < minChildren || info.count > _maxEntries) {
        throw StateError(
          'Internal node count ${info.count} out of '
          '[$minChildren, $_maxEntries]',
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
        if (i > 0) {
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
    final minEntries =
        snapshot.height == 1 || identical(node, snapshot.tail) ? 1 : _minFill;
    if (info.count < minEntries || info.count > _maxEntries) {
      throw StateError(
        'Leaf count ${info.count} out of [$minEntries, $_maxEntries]',
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
    test('empty tree and iterable properties', () {
      final tree = BPlusTree<int, String>(_intCompare);
      verifyInvariants(tree, _intCompare);
      expect(tree.length, 0);
      expect(tree.isEmpty, true);
      expect(tree.isNotEmpty, false);
      expect(tree.keys, isEmpty);
      expect(tree.keys.isEmpty, true);
      expect(tree.keys.isNotEmpty, false);
      expect(tree.keys.length, 0);
      expect(tree.values, isEmpty);
      expect(tree.values.isEmpty, true);
      expect(tree.values.isNotEmpty, false);
      expect(tree.values.length, 0);
      expect(tree.get(1), null);
      expect(tree.containsKey(1), false);
      expect(tree.delete(1), null);
      expect(tree.valuesFromKey(1), isEmpty);
      expect(() => tree.getAt(0), throwsRangeError);
      expect(() => tree.getAt(-1), throwsRangeError);
      expect(() => tree.getAt(1), throwsRangeError);
      expect(() => tree.getKeyAt(0), throwsRangeError);
      expect(() => tree.getKeyAt(-1), throwsRangeError);
      expect(() => tree.getKeyAt(1), throwsRangeError);
    });

    test(
      'ascending inserts trigger tail fast path across internal splits',
      () {
        final tree = BPlusTree<int, String>(_intCompare);
        // > 5923 ascending entries splits a non-root internal child at level 1,
        // exercising ancestor count updates in _propagateSplitUp.
        const count = 6500;
        for (var i = 0; i < count; i++) {
          expect(tree.insert(i, 'v$i'), null);
          if (i < 300 || i % 250 == 0 || i == count - 1) {
            verifyInvariants(tree, _intCompare);
          }
        }

        expect(tree.debugSnapshot().height, 3);
        expect(tree.length, count);
        expect(tree.isEmpty, false);
        expect(tree.isNotEmpty, true);
        expect(tree.keys.isEmpty, false);
        expect(tree.keys.isNotEmpty, true);
        expect(tree.keys.length, count);
        expect(tree.values.isEmpty, false);
        expect(tree.values.isNotEmpty, true);
        expect(tree.values.length, count);

        for (var i = 0; i < count; i++) {
          expect(tree.containsKey(i), true);
          expect(tree.get(i), 'v$i');
          expect(tree.getAt(i), 'v$i');
          expect(tree.getKeyAt(i), i);
        }
        expect(tree.containsKey(-1), false);
        expect(tree.containsKey(count), false);
        expect(() => tree.getAt(-1), throwsRangeError);
        expect(() => tree.getAt(count), throwsRangeError);
        expect(() => tree.getAt(count + 1), throwsRangeError);
        expect(() => tree.getKeyAt(-1), throwsRangeError);
        expect(() => tree.getKeyAt(count), throwsRangeError);
        expect(() => tree.getKeyAt(count + 1), throwsRangeError);
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

      expect(tree.debugSnapshot().height, 3);
      expect(tree.length, count);
      expect(tree.keys, List.generate(count, (i) => i));
      for (var i = 0; i < count; i++) {
        expect(tree.get(i), i * 2);
        expect(tree.getAt(i), i * 2);
        expect(tree.getKeyAt(i), i);
      }
    });

    test('non-tail-append split of full _tail updates _tail', () {
      final tree = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < _maxEntries; i++) {
        expect(tree.insert(i * 2, i), null);
      }
      expect(tree.debugSnapshot().height, 1);

      // Insert < tail.last into a full 63-entry _tail so the leaf splits and
      // updates _tail.
      expect(tree.insert(123, 123), null);
      verifyInvariants(tree, _intCompare);
      expect(tree.debugSnapshot().height, 2);
      expect(tree.length, 64);

      expect(tree.insert(200, 200), null);
      verifyInvariants(tree, _intCompare);
      expect(tree.getKeyAt(64), 200);
      expect(tree.get(123), 123);
    });

    test('getAt and getKeyAt RangeError across heights 1, 2, and 3', () {
      for (final (size, expectedHeight) in [(10, 1), (100, 2), (4100, 3)]) {
        final tree = BPlusTree<int, int>(_intCompare);
        for (var i = 0; i < size; i++) {
          tree.insert(i, i);
        }
        expect(tree.debugSnapshot().height, expectedHeight);
        for (final badIndex in [-1, size, size + 1]) {
          expect(() => tree.getAt(badIndex), throwsRangeError);
          expect(() => tree.getKeyAt(badIndex), throwsRangeError);
        }
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

      // Ascending deletion (exercises left-edge borrows and merges).
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

      // Descending deletion (exercises tail & left-neighbor borrows/merges).
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

    test('boundary-merge regression keeps strict fill invariants', () {
      final tree = BPlusTree<int, int>(_intCompare);
      final ref = SplayTreeMap<int, int>(_intCompare);
      for (var i = 0; i < 4032; i++) {
        tree.insert(i, i);
        ref[i] = i;
      }
      verifyInvariants(tree, _intCompare);

      for (var i = 31 * 63; i <= 31 * 63 + 61; i++) {
        expect(tree.delete(i), ref.remove(i));
        verifyInvariants(tree, _intCompare);
      }
      for (var i = 32 * 63; i <= 32 * 63 + 61; i++) {
        expect(tree.delete(i), ref.remove(i));
        verifyInvariants(tree, _intCompare);
      }
      for (var i = 34 * 63; i <= 34 * 63 + 31; i++) {
        expect(tree.delete(i), ref.remove(i));
        verifyInvariants(tree, _intCompare);
      }
      for (var i = 35 * 63; i <= 35 * 63 + 31; i++) {
        expect(tree.delete(i), ref.remove(i));
        verifyInvariants(tree, _intCompare);
      }

      expect(tree.length, ref.length);
      expect(tree.keys.toList(), ref.keys.toList());
      expect(tree.values.toList(), ref.values.toList());
    });

    test('leaf rebalancing covers borrow and merge paths', () {
      // 1. borrowFromLeft on an interior leaf.
      final borrowLeftInterior = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 127; i++) {
        borrowLeftInterior.insert(i, i);
      }
      for (var i = 63; i <= 94; i++) {
        expect(borrowLeftInterior.delete(i), i);
      }
      verifyInvariants(borrowLeftInterior, _intCompare);
      final blSnap = borrowLeftInterior.debugSnapshot();
      final blRoot = blSnap.inspect(blSnap.root);
      final blChildren = blRoot.children ?? fail('Expected root children');
      expect(blSnap.inspect(blChildren[0] as Object).count, 62);
      expect(blSnap.inspect(blChildren[1] as Object).count, 32);

      // 2. borrowFromLeft on a 1-entry _tail leaf when left has > 32 entries.
      final borrowLeftTail = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 64; i++) {
        borrowLeftTail.insert(i, i);
      }
      expect(borrowLeftTail.delete(63), 63);
      verifyInvariants(borrowLeftTail, _intCompare);
      final btSnap = borrowLeftTail.debugSnapshot();
      expect(btSnap.height, 2);
      expect(btSnap.inspect(btSnap.tail).count, 1);
      expect(btSnap.inspect(btSnap.head).count, 62);
      expect(borrowLeftTail.keys.toList(), List.generate(63, (i) => i));

      // 3. borrowFromRight when childIdx == 0.
      final borrowRight = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 126; i++) {
        borrowRight.insert(i, i);
      }
      for (var i = 0; i < 32; i++) {
        expect(borrowRight.delete(i), i);
      }
      verifyInvariants(borrowRight, _intCompare);
      final brSnap = borrowRight.debugSnapshot();
      final brRoot = brSnap.inspect(brSnap.root);
      final brChildren = brRoot.children ?? fail('Expected root children');
      expect(brSnap.inspect(brChildren[0] as Object).count, 32);
      expect(brSnap.inspect(brChildren[1] as Object).count, 62);

      // 4. Leaf left-merge on an interior leaf (leaves _tail unchanged).
      final leftMergeInterior = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 127; i++) {
        leftMergeInterior.insert(i, i);
      }
      for (var i = 0; i < 31; i++) {
        expect(leftMergeInterior.delete(i), i);
      }
      for (var i = 63; i <= 94; i++) {
        expect(leftMergeInterior.delete(i), i);
      }
      verifyInvariants(leftMergeInterior, _intCompare);
      final lmiSnap = leftMergeInterior.debugSnapshot();
      expect(lmiSnap.inspect(lmiSnap.root).count, 2);
      expect(lmiSnap.inspect(lmiSnap.tail).keys[0], 126);
      expect(leftMergeInterior.insert(200, 200), null);
      verifyInvariants(leftMergeInterior, _intCompare);

      // 5. Leaf left-merge on _tail updates _tail and collapses root.
      final leftMergeTail = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 64; i++) {
        leftMergeTail.insert(i, i);
      }
      for (var i = 0; i < 31; i++) {
        expect(leftMergeTail.delete(i), i);
      }
      expect(leftMergeTail.delete(63), 63);
      verifyInvariants(leftMergeTail, _intCompare);
      expect(leftMergeTail.debugSnapshot().height, 1);
      expect(leftMergeTail.length, 32);
      expect(leftMergeTail.insert(100, 100), null);
      verifyInvariants(leftMergeTail, _intCompare);
      expect(leftMergeTail.getKeyAt(32), 100);

      // 6. Leaf right-merge on non-tail leaf keeps _tail intact.
      final rightMergeInterior = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 127; i++) {
        rightMergeInterior.insert(i, i);
      }
      for (var i = 63; i <= 93; i++) {
        expect(rightMergeInterior.delete(i), i);
      }
      for (var i = 0; i < 32; i++) {
        expect(rightMergeInterior.delete(i), i);
      }
      verifyInvariants(rightMergeInterior, _intCompare);
      expect(
        rightMergeInterior.keys.toList(),
        [
          ...List.generate(31, (i) => 32 + i),
          ...List.generate(32, (i) => 94 + i),
          126,
        ],
      );

      // 7. Leaf right-merge with _tail updates _tail and collapses root.
      final rightMergeTail = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 64; i++) {
        rightMergeTail.insert(i, i);
      }
      for (var i = 0; i < 31; i++) {
        expect(rightMergeTail.delete(i), i);
      }
      expect(rightMergeTail.delete(31), 31);
      verifyInvariants(rightMergeTail, _intCompare);
      expect(rightMergeTail.debugSnapshot().height, 1);
      expect(rightMergeTail.length, 32);
      expect(rightMergeTail.keys.toList(), List.generate(32, (i) => i + 32));
      expect(rightMergeTail.insert(100, 100), null);
      verifyInvariants(rightMergeTail, _intCompare);
      expect(rightMergeTail.getKeyAt(32), 100);
    });

    test('internal rebalancing covers borrow, merge, and root collapse', () {
      void expectRootState(
        BPlusTree<int, int> tree,
        int expectedHeight,
        List<int> childCounts,
      ) {
        verifyInvariants(tree, _intCompare);
        final snap = tree.debugSnapshot();
        expect(snap.height, expectedHeight);
        final rootInfo = snap.inspect(snap.root);
        expect(rootInfo.count, childCounts.length);
        final children = rootInfo.children ?? fail('Expected root children');
        for (var i = 0; i < childCounts.length; i++) {
          expect(
            snap.inspect(children[i] as Object).count,
            childCounts[i],
          );
        }
      }

      // 1. Internal borrowFromLeft (childIdx > 0).
      final borrowLeft = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 3970; i++) {
        borrowLeft.insert(i * 100, i);
      }
      borrowLeft.insert(1, -1);
      expectRootState(borrowLeft, 3, [33, 32]);
      for (var i = 33 * 63; i < 33 * 63 + 31; i++) {
        expect(borrowLeft.delete(i * 100), i);
      }
      for (var i = 32 * 63; i < 32 * 63 + 32; i++) {
        expect(borrowLeft.delete(i * 100), i);
      }
      expectRootState(borrowLeft, 3, [32, 32]);
      expect(borrowLeft.get(1), -1);
      expect(borrowLeft.get(3969 * 100), 3969);

      // 2. Internal borrowFromRight (childIdx == 0).
      final borrowRight = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 3970; i++) {
        borrowRight.insert(i * 100, i);
      }
      borrowRight.insert(32 * 63 * 100 + 1, -1);
      expectRootState(borrowRight, 3, [32, 33]);
      for (var i = 63; i < 63 + 31; i++) {
        expect(borrowRight.delete(i * 100), i);
      }
      for (var i = 0; i < 32; i++) {
        expect(borrowRight.delete(i * 100), i);
      }
      expectRootState(borrowRight, 3, [32, 32]);
      expect(borrowRight.get(32 * 63 * 100 + 1), -1);
      expect(borrowRight.get(3969 * 100), 3969);

      // 3. Internal left-merge (childIdx > 0) + root collapse 3 -> 2.
      final mergeLeft = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 3970; i++) {
        mergeLeft.insert(i * 100, i);
      }
      expectRootState(mergeLeft, 3, [32, 32]);
      for (var i = 33 * 63; i < 33 * 63 + 31; i++) {
        expect(mergeLeft.delete(i * 100), i);
      }
      for (var i = 32 * 63; i < 32 * 63 + 32; i++) {
        expect(mergeLeft.delete(i * 100), i);
      }
      verifyInvariants(mergeLeft, _intCompare);
      expect(mergeLeft.debugSnapshot().height, 2);
      expect(
        mergeLeft.debugSnapshot().inspect(mergeLeft.debugSnapshot().root).count,
        63,
      );

      // 4. Internal right-merge (childIdx == 0) + root collapse 3 -> 2 -> 1.
      final mergeRight = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 3970; i++) {
        mergeRight.insert(i * 100, i);
      }
      expectRootState(mergeRight, 3, [32, 32]);
      for (var i = 63; i < 63 + 31; i++) {
        expect(mergeRight.delete(i * 100), i);
      }
      for (var i = 0; i < 32; i++) {
        expect(mergeRight.delete(i * 100), i);
      }
      verifyInvariants(mergeRight, _intCompare);
      expect(mergeRight.debugSnapshot().height, 2);
      expect(
        mergeRight
            .debugSnapshot()
            .inspect(mergeRight.debugSnapshot().root)
            .count,
        63,
      );

      final remainingKeys = mergeRight.keys.toList();
      for (var i = 0; i < remainingKeys.length - 32; i++) {
        mergeRight.delete(remainingKeys[i]);
      }
      verifyInvariants(mergeRight, _intCompare);
      expect(mergeRight.debugSnapshot().height, 1);
      expect(mergeRight.length, 32);

      // 5. Internal merge with non-collapsing root (root.count == 3 -> 2).
      final nonCollapse = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 6500; i++) {
        nonCollapse.insert(i, i);
      }
      verifyInvariants(nonCollapse, _intCompare);
      final ncSnap = nonCollapse.debugSnapshot();
      expect(ncSnap.height, 3);
      final ncRoot = ncSnap.inspect(ncSnap.root);
      expect(ncRoot.count, 3);
      final ncChildren = ncRoot.children ?? fail('Expected root children');
      final midNode = ncChildren[1] as Object;
      final midInfo = ncSnap.inspect(midNode);
      final midLeaves = midInfo.children ?? fail('Expected internal children');
      final firstMidLeaf = ncSnap.inspect(midLeaves[0] as Object);
      final minMidKey = firstMidLeaf.keys[0] as int;
      final lastMidLeaf =
          ncSnap.inspect(midLeaves[midInfo.count - 1] as Object);
      final maxMidKey = lastMidLeaf.keys[lastMidLeaf.count - 1] as int;
      // Drain the middle internal node down to 31 children so it merges left
      // while root keeps 2 children and stays at height 3.
      for (var k = minMidKey; k <= maxMidKey; k++) {
        nonCollapse.delete(k);
        if (nonCollapse.debugSnapshot().inspect(ncSnap.root).count == 2) {
          break;
        }
      }
      verifyInvariants(nonCollapse, _intCompare);
      expect(nonCollapse.debugSnapshot().height, 3);
      expect(
        nonCollapse
            .debugSnapshot()
            .inspect(nonCollapse.debugSnapshot().root)
            .count,
        2,
      );
    });

    test('valuesFromKey across leaf boundaries and missing keys', () {
      final tree = BPlusTree<int, String>(_intCompare);
      for (var i = 0; i < 200; i += 2) {
        tree.insert(i, 'v$i');
      }

      expect(tree.valuesFromKey(1), isEmpty);
      expect(tree.valuesFromKey(-5), isEmpty);
      expect(tree.valuesFromKey(999), isEmpty);

      final slice = tree.valuesFromKey(120);
      final expected = [for (var i = 120; i < 200; i += 2) 'v$i'];
      expect(slice, expected);
      expect(slice, expected);

      expect(tree.valuesFromKey(198), ['v198']);
      expect(
        tree.valuesFromKey(0),
        [for (var i = 0; i < 200; i += 2) 'v$i'],
      );
    });

    test('valuesFromKey handles mid-iteration leaf shrinkage safely', () {
      // Single-leaf shrinkage.
      final singleLeaf = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 10; i++) {
        singleLeaf.insert(i, i);
      }
      final singleCollected = <int>[];
      for (final val in singleLeaf.valuesFromKey(2)) {
        singleCollected.add(val);
        if (val == 3) {
          for (var i = 4; i < 10; i++) {
            singleLeaf.delete(i);
          }
        }
      }
      expect(singleCollected, [2, 3]);
      verifyInvariants(singleLeaf, _intCompare);

      // Multi-leaf shrinkage: shrink current leaf (0..62) from 63 down to 32
      // entries while iterating inside it; must not cast nulled slots as V and
      // must still yield subsequent leaves cleanly.
      final multiLeaf = BPlusTree<int, int>(_intCompare);
      for (var i = 0; i < 150; i++) {
        multiLeaf.insert(i, i);
      }
      final multiCollected = <int>[];
      for (final val in multiLeaf.valuesFromKey(10)) {
        multiCollected.add(val);
        if (val == 15) {
          for (var i = 16; i <= 46; i++) {
            multiLeaf.delete(i);
          }
        }
      }
      verifyInvariants(multiLeaf, _intCompare);
      expect(
        multiCollected,
        [
          10,
          11,
          12,
          13,
          14,
          15,
          for (var i = 47; i < 150; i++) i,
        ],
      );
    });

    test('custom comparators and nullable keys and values', () {
      final revTree = BPlusTree<int, String?>(_reverseIntCompare);
      for (var i = 0; i < 100; i++) {
        revTree.insert(i, i.isEven ? null : 'v$i');
      }
      verifyInvariants(revTree, _reverseIntCompare);
      expect(revTree.keys, List.generate(100, (i) => 99 - i));
      for (var i = 0; i < 100; i++) {
        expect(revTree.containsKey(i), true);
        expect(revTree.get(i), i.isEven ? null : 'v$i');
      }
      expect(revTree.getAt(0), 'v99');
      expect(revTree.getAt(1), null);
      expect(revTree.getKeyAt(0), 99);
      expect(revTree.valuesFromKey(2).toList(), [null, 'v1', null]);
      expect(revTree.delete(2), null);
      expect(revTree.containsKey(2), false);
      verifyInvariants(revTree, _reverseIntCompare);

      // Nullable keys and nullable values.
      final nullableTree = BPlusTree<int?, String?>(_nullableIntCompare);
      nullableTree.insert(null, 'null-val');
      for (var i = 0; i < 100; i++) {
        nullableTree.insert(i, i.isOdd ? null : 'k$i');
      }
      verifyInvariants(nullableTree, _nullableIntCompare);
      expect(nullableTree.get(null), 'null-val');
      expect(nullableTree.containsKey(null), true);
      expect(nullableTree.getKeyAt(0), null);
      expect(nullableTree.getAt(0), 'null-val');
      expect(nullableTree.delete(null), 'null-val');
      expect(nullableTree.containsKey(null), false);
      verifyInvariants(nullableTree, _nullableIntCompare);

      // Custom comparator returning arbitrary negative/positive ints.
      int diffCompare(int a, int b) => a - b;
      final diffTree = BPlusTree<int, int>(diffCompare);
      for (var i = 0; i < 300; i++) {
        diffTree.insert(i * 7, i);
      }
      for (var i = 0; i < 300; i += 2) {
        expect(diffTree.delete(i * 7), i);
      }
      verifyInvariants(diffTree, diffCompare);
      expect(diffTree.length, 150);
    });

    test('Hive defaultKeyComparator mixed int and String fuzz (5500 ops)', () {
      final tree = BPlusTree<dynamic, int>(defaultKeyComparator);
      final ref = SplayTreeMap<dynamic, int>(defaultKeyComparator);
      final rng = Random(2026);
      final longStr = 'x' * 255;
      final keyPool = <dynamic>[
        0,
        1,
        0x7FFFFFFF,
        0xFFFFFFFF,
        '',
        '0',
        'a',
        'z',
        '🔑',
        '日本語',
        longStr,
        for (var i = 0; i < 500; i++) i * 3 + 2,
        for (var i = 0; i < 500; i++) 'k_${i.toString().padLeft(4, '0')}',
      ];

      for (var step = 0; step < 5500; step++) {
        final key = keyPool[rng.nextInt(keyPool.length)];
        final op = rng.nextInt(100);
        if (op < 55) {
          final val = rng.nextInt(100000);
          final expected = ref[key];
          ref[key] = val;
          expect(tree.insert(key, val), expected);
        } else if (op < 85) {
          final expected = ref.remove(key);
          expect(tree.delete(key), expected);
        } else if (op < 93 && ref.isNotEmpty) {
          final idx = rng.nextInt(ref.length);
          final expectedKey = ref.keys.elementAt(idx);
          expect(tree.getKeyAt(idx), expectedKey);
          expect(tree.getAt(idx), ref[expectedKey]);
          expect(tree.get(expectedKey), ref[expectedKey]);
          expect(tree.containsKey(expectedKey), true);
        } else if (ref.isNotEmpty) {
          final idx = rng.nextInt(ref.length);
          final startKey = ref.keys.elementAt(idx);
          expect(
            tree.valuesFromKey(startKey).take(15).toList(),
            ref.keys.skip(idx).take(15).map((k) => ref[k]).toList(),
          );
        }

        expect(tree.length, ref.length);
        if (step % 500 == 0 || step == 5499) {
          verifyInvariants(tree, defaultKeyComparator);
          expect(tree.keys.toList(), ref.keys.toList());
          expect(tree.values.toList(), ref.values.toList());
        }
      }
    });

    test('comparator exception cleans _pathNodes and leaves tree intact', () {
      var armed = true;
      int? throwingSentinel = -999;

      int guardedCompare(int a, int b) {
        // Allow tail fast-path guard against tail.last (4099) to pass so
        // insert() reaches _findLeafWithPath/_findInLeaf and exercises catch.
        if (armed &&
            a != 4099 &&
            b != 4099 &&
            (a == throwingSentinel || b == throwingSentinel)) {
          throw StateError('comparator failure');
        }
        return a.compareTo(b);
      }

      final tree = BPlusTree<int, int>(guardedCompare);
      for (var i = 0; i < 4100; i++) {
        tree.insert(i, i * 10);
      }
      verifyInvariants(tree, _intCompare);

      // Sentinel < tail.last enters _findLeafWithPath during insert and delete.
      for (final op in <void Function()>[
        () => tree.insert(-999, 1),
        () => tree.delete(-999),
        () => tree.get(-999),
        () => tree.containsKey(-999),
        () => tree.valuesFromKey(-999),
      ]) {
        expect(op, throwsStateError);
        armed = false;
        verifyInvariants(tree, _intCompare);
        armed = true;
      }

      // Sentinel present at leaf depth populates _pathNodes before throwing
      // in _findInLeaf.
      throwingSentinel = 50;
      for (final op in <void Function()>[
        () => tree.insert(50, -1),
        () => tree.delete(50),
      ]) {
        expect(op, throwsStateError);
        armed = false;
        verifyInvariants(tree, _intCompare);
        expect(tree.get(50), 500);
        armed = true;
      }

      armed = false;
      expect(tree.length, 4100);
      tree.clear();
      verifyInvariants(tree, _intCompare);
      for (var i = 0; i < 150; i++) {
        tree.insert(i, i);
      }
      verifyInvariants(tree, _intCompare);
      expect(tree.length, 150);
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

    test('every-step invariant fuzz test against SplayTreeMap (3000 ops)', () {
      final tree = BPlusTree<int, int>(_intCompare);
      final ref = SplayTreeMap<int, int>(_intCompare);
      final rng = Random(777);
      var tailSeq = 5000;

      for (var step = 0; step < 3000; step++) {
        final op = rng.nextInt(100);
        if (op < 15) {
          final key = tailSeq++;
          final val = rng.nextInt(100000);
          final expected = ref[key];
          ref[key] = val;
          expect(tree.insert(key, val), expected);
        } else if (op < 60) {
          final key = rng.nextInt(1500);
          final val = rng.nextInt(100000);
          final expected = ref[key];
          ref[key] = val;
          expect(tree.insert(key, val), expected);
        } else {
          final key = rng.nextInt(1500);
          final expected = ref.remove(key);
          expect(tree.delete(key), expected);
        }

        verifyInvariants(tree, _intCompare);
        expect(tree.length, ref.length);
      }
      expect(tree.keys.toList(), ref.keys.toList());
      expect(tree.values.toList(), ref.values.toList());
    });

    test('fill and drain wave cycles', () {
      final tree = BPlusTree<int, int>(_intCompare);
      final ref = SplayTreeMap<int, int>(_intCompare);
      final rng = Random(31415);

      // Wave 1: grow to 4500 with mixed inserts, then range-delete to 0.
      final keys1 = List.generate(4500, (i) => i)..shuffle(rng);
      for (final k in keys1) {
        tree.insert(k, k * 3);
        ref[k] = k * 3;
      }
      verifyInvariants(tree, _intCompare);
      for (var k = 1500; k < 3000; k++) {
        expect(tree.delete(k), ref.remove(k));
      }
      verifyInvariants(tree, _intCompare);
      keys1.shuffle(rng);
      for (final k in keys1) {
        expect(tree.delete(k), ref.remove(k));
      }
      verifyInvariants(tree, _intCompare);
      expect(tree.length, 0);

      // Wave 2: regrow ascending to 4500, random delete to 0.
      for (var k = 0; k < 4500; k++) {
        tree.insert(k, k);
        ref[k] = k;
      }
      verifyInvariants(tree, _intCompare);
      final keys2 = List.generate(4500, (i) => i)..shuffle(rng);
      for (var i = 0; i < keys2.length; i++) {
        final k = keys2[i];
        expect(tree.delete(k), ref.remove(k));
        if (i % 500 == 0 || i == keys2.length - 1) {
          verifyInvariants(tree, _intCompare);
        }
      }
      expect(tree.length, 0);

      // Wave 3: regrow, clear, and regrow again.
      for (var k = 0; k < 1000; k++) {
        tree.insert(k, k);
      }
      tree.clear();
      verifyInvariants(tree, _intCompare);
      for (var k = 0; k < 2000; k++) {
        tree.insert(k * 2, k);
      }
      verifyInvariants(tree, _intCompare);
      expect(tree.length, 2000);
      expect(tree.get(1998), 999);
    });
  });
}
