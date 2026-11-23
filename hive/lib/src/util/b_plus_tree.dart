import 'dart:collection';
import 'dart:typed_data';

import 'package:hive_ce/src/binary/frame.dart';
import 'package:meta/meta.dart';

const _order = 64;
const _minFill = 32;
const _nullLength = -1;

final class _InternalNode<K> {
  final keys = List<K?>.filled(_order - 1, null);
  final children = List<Object?>.filled(_order, null);
  final counts = Int32List(_order);
  var count = 0;
}

abstract class _BPlusLeafBase<K> {
  final keys = List<K?>.filled(_order, null);
  var count = 0;
  _BPlusLeafBase<K>? next;

  void removeAt(int index);

  void borrowFromLeft(covariant _BPlusLeafBase<K> left);

  void borrowFromRight(covariant _BPlusLeafBase<K> right);

  void mergeWithRight(covariant _BPlusLeafBase<K> right);
}

final class _ValueLeaf<K, V> extends _BPlusLeafBase<K> {
  final values = List<V?>.filled(_order, null);

  @override
  void removeAt(int index) {
    final newCount = count - 1;
    for (var i = index; i < newCount; i++) {
      keys[i] = keys[i + 1];
      values[i] = values[i + 1];
    }
    keys[newCount] = null;
    values[newCount] = null;
    count = newCount;
  }

  @override
  void borrowFromLeft(_ValueLeaf<K, V> left) {
    final leftLast = left.count - 1;
    for (var i = count; i > 0; i--) {
      keys[i] = keys[i - 1];
      values[i] = values[i - 1];
    }
    keys[0] = left.keys[leftLast];
    values[0] = left.values[leftLast];
    left.keys[leftLast] = null;
    left.values[leftLast] = null;
    left.count = leftLast;
    count++;
  }

  @override
  void borrowFromRight(_ValueLeaf<K, V> right) {
    keys[count] = right.keys[0];
    values[count] = right.values[0];
    count++;

    final newRightCount = right.count - 1;
    for (var i = 0; i < newRightCount; i++) {
      right.keys[i] = right.keys[i + 1];
      right.values[i] = right.values[i + 1];
    }
    right.keys[newRightCount] = null;
    right.values[newRightCount] = null;
    right.count = newRightCount;
  }

  @override
  void mergeWithRight(_ValueLeaf<K, V> right) {
    final rCount = right.count;
    final offset = count;
    for (var i = 0; i < rCount; i++) {
      keys[offset + i] = right.keys[i];
      values[offset + i] = right.values[i];
      right.keys[i] = null;
      right.values[i] = null;
    }
    count = offset + rCount;
    right.count = 0;
    next = right.next;
    right.next = null;
  }
}

final class _LazyLeaf<K> extends _BPlusLeafBase<K> {
  final offsets = Float64List(_order);
  final lengths = Int32List(_order);

  @override
  void removeAt(int index) {
    final newCount = count - 1;
    for (var i = index; i < newCount; i++) {
      keys[i] = keys[i + 1];
      offsets[i] = offsets[i + 1];
      lengths[i] = lengths[i + 1];
    }
    keys[newCount] = null;
    count = newCount;
  }

  @override
  void borrowFromLeft(_LazyLeaf<K> left) {
    final leftLast = left.count - 1;
    for (var i = count; i > 0; i--) {
      keys[i] = keys[i - 1];
      offsets[i] = offsets[i - 1];
      lengths[i] = lengths[i - 1];
    }
    keys[0] = left.keys[leftLast];
    offsets[0] = left.offsets[leftLast];
    lengths[0] = left.lengths[leftLast];
    left.keys[leftLast] = null;
    left.count = leftLast;
    count++;
  }

  @override
  void borrowFromRight(_LazyLeaf<K> right) {
    keys[count] = right.keys[0];
    offsets[count] = right.offsets[0];
    lengths[count] = right.lengths[0];
    count++;

    final newRightCount = right.count - 1;
    for (var i = 0; i < newRightCount; i++) {
      right.keys[i] = right.keys[i + 1];
      right.offsets[i] = right.offsets[i + 1];
      right.lengths[i] = right.lengths[i + 1];
    }
    right.keys[newRightCount] = null;
    right.count = newRightCount;
  }

  @override
  void mergeWithRight(_LazyLeaf<K> right) {
    final rCount = right.count;
    final offset = count;
    for (var i = 0; i < rCount; i++) {
      keys[offset + i] = right.keys[i];
      offsets[offset + i] = right.offsets[i];
      lengths[offset + i] = right.lengths[i];
      right.keys[i] = null;
    }
    count = offset + rCount;
    right.count = 0;
    next = right.next;
    right.next = null;
  }
}

abstract class _BPlusTreeBase<K, L extends _BPlusLeafBase<K>> {
  final Comparator<K> _comparator;

  late Object _root;
  late L _head;
  late L _tail;
  var _height = 1;
  var _length = 0;

  var _pathNodes = List<_InternalNode<K>?>.filled(16, null);
  var _pathIndices = Int32List(16);

  _BPlusTreeBase(this._comparator) {
    final leaf = _createLeaf();
    _root = leaf;
    _head = leaf;
    _tail = leaf;
  }

  L _createLeaf();

  /// Not part of public API
  int get length => _length;

  /// Not part of public API
  bool get isEmpty => _length == 0;

  /// Not part of public API
  bool get isNotEmpty => _length > 0;

  /// Not part of public API
  Iterable<K> get keys => _BPlusKeyIterable<K, L>(this);

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool containsKey(K key) {
    if (_length == 0) return false;
    final leaf = _findLeaf(key);
    return _findInLeaf(leaf, key) >= 0;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  K getKeyAt(int index) {
    final (leaf, slot) = _locateAt(index);
    return leaf.keys[slot] as K;
  }

  /// Not part of public API
  void clear() {
    final leaf = _createLeaf();
    _root = leaf;
    _head = leaf;
    _tail = leaf;
    _height = 1;
    _length = 0;
    _pathNodes.fillRange(0, _pathNodes.length, null);
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  (L, int) _locateAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', _length);
    var node = _root;
    var remaining = index;
    for (var level = 0; level < _height - 1; level++) {
      final internal = node as _InternalNode<K>;
      final counts = internal.counts;
      final childCount = internal.count;
      var i = 0;
      while (i < childCount - 1 && remaining >= counts[i]) {
        remaining -= counts[i];
        i++;
      }
      node = internal.children[i]!;
    }
    return (node as L, remaining);
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int _findChildIndex(_InternalNode<K> node, K key) {
    final keys = node.keys;
    var lo = 0;
    var hi = node.count - 2;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final cmp = _comparator(key, keys[mid] as K);
      if (cmp > 0) {
        lo = mid + 1;
      } else if (cmp < 0) {
        hi = mid - 1;
      } else {
        return mid + 1;
      }
    }
    return lo;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  L _findLeaf(K key) {
    var node = _root;
    for (var level = 0; level < _height - 1; level++) {
      final internal = node as _InternalNode<K>;
      node = internal.children[_findChildIndex(internal, key)]!;
    }
    return node as L;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  L _findLeafWithPath(K key) {
    var node = _root;
    final internalLevels = _height - 1;
    for (var level = 0; level < internalLevels; level++) {
      final internal = node as _InternalNode<K>;
      final childIdx = _findChildIndex(internal, key);
      _pathNodes[level] = internal;
      _pathIndices[level] = childIdx;
      node = internal.children[childIdx]!;
    }
    return node as L;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int _findInLeaf(L leaf, K key) {
    final keys = leaf.keys;
    var lo = 0;
    var hi = leaf.count - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final cmp = _comparator(key, keys[mid] as K);
      if (cmp > 0) {
        lo = mid + 1;
      } else if (cmp < 0) {
        hi = mid - 1;
      } else {
        return mid;
      }
    }
    return -(lo + 1);
  }

  void _ensurePathCapacity() {
    if (_height < _pathNodes.length) return;
    final newLen = _pathNodes.length * 2;
    final newNodes = List<_InternalNode<K>?>.filled(newLen, null);
    newNodes.setRange(0, _pathNodes.length, _pathNodes);
    _pathNodes = newNodes;

    final newIndices = Int32List(newLen);
    newIndices.setRange(0, _pathIndices.length, _pathIndices);
    _pathIndices = newIndices;
  }

  void _clearPath(int depth) {
    for (var i = 0; i < depth; i++) {
      _pathNodes[i] = null;
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _incrementRightSpine() {
    var node = _root;
    for (var level = 0; level < _height - 1; level++) {
      final internal = node as _InternalNode<K>;
      final last = internal.count - 1;
      internal.counts[last]++;
      node = internal.children[last]!;
    }
  }

  void _insertTailLeaf(K sepKey, L newTail) {
    _ensurePathCapacity();
    var node = _root;
    final internalLevels = _height - 1;
    for (var level = 0; level < internalLevels; level++) {
      final internal = node as _InternalNode<K>;
      final last = internal.count - 1;
      _pathNodes[level] = internal;
      _pathIndices[level] = last;
      node = internal.children[last]!;
    }
    _propagateSplitUp(internalLevels, sepKey, newTail, _order, 1);
  }

  void _propagateSplitUp(
    int depth,
    K sepKey,
    Object rightChild,
    int leftNewCount,
    int rightNewCount,
  ) {
    var currentSep = sepKey;
    var currentRight = rightChild;
    var currentLeftCount = leftNewCount;
    var currentRightCount = rightNewCount;

    for (var level = depth - 1; level >= 0; level--) {
      final node = _pathNodes[level]!;
      final idx = _pathIndices[level];
      node.counts[idx] = currentLeftCount;

      if (node.count < _order) {
        final insertChildPos = idx + 1;
        for (var i = node.count - 1; i > idx; i--) {
          node.keys[i] = node.keys[i - 1];
        }
        for (var i = node.count; i > insertChildPos; i--) {
          node.children[i] = node.children[i - 1];
          node.counts[i] = node.counts[i - 1];
        }
        node.keys[idx] = currentSep;
        node.children[insertChildPos] = currentRight;
        node.counts[insertChildPos] = currentRightCount;
        node.count++;

        for (var up = level - 1; up >= 0; up--) {
          _pathNodes[up]!.counts[_pathIndices[up]]++;
        }
        _clearPath(depth);
        return;
      }

      // Internal node is full (_order == 64): split into 32 left, 33 right.
      final newRight = _InternalNode<K>();
      final lKeys = node.keys;
      final lChildren = node.children;
      final lCounts = node.counts;
      final rKeys = newRight.keys;
      final rChildren = newRight.children;
      final rCounts = newRight.counts;
      final K promoted;

      if (idx < _minFill - 1) {
        promoted = lKeys[_minFill - 2] as K;
        for (var i = _minFill - 1; i < _order - 1; i++) {
          final dst = i - (_minFill - 1);
          rKeys[dst] = lKeys[i];
          lKeys[i] = null;
        }
        for (var i = _minFill - 1; i < _order; i++) {
          final dst = i - (_minFill - 1);
          rChildren[dst] = lChildren[i];
          rCounts[dst] = lCounts[i];
          lChildren[i] = null;
          lCounts[i] = 0;
        }

        for (var i = _minFill - 2; i > idx; i--) {
          lKeys[i] = lKeys[i - 1];
        }
        lKeys[idx] = currentSep;

        final insertChildPos = idx + 1;
        for (var i = _minFill - 1; i > insertChildPos; i--) {
          lChildren[i] = lChildren[i - 1];
          lCounts[i] = lCounts[i - 1];
        }
        lChildren[insertChildPos] = currentRight;
        lCounts[insertChildPos] = currentRightCount;
      } else if (idx == _minFill - 1) {
        promoted = currentSep;
        for (var i = _minFill - 1; i < _order - 1; i++) {
          final dst = i - (_minFill - 1);
          rKeys[dst] = lKeys[i];
          lKeys[i] = null;
        }
        rChildren[0] = currentRight;
        rCounts[0] = currentRightCount;
        for (var i = _minFill; i < _order; i++) {
          final dst = i - _minFill + 1;
          rChildren[dst] = lChildren[i];
          rCounts[dst] = lCounts[i];
          lChildren[i] = null;
          lCounts[i] = 0;
        }
      } else {
        promoted = lKeys[_minFill - 1] as K;
        lKeys[_minFill - 1] = null;

        final rightKeyInsert = idx - _minFill;
        for (var i = _minFill; i < idx; i++) {
          final dst = i - _minFill;
          rKeys[dst] = lKeys[i];
          lKeys[i] = null;
        }
        rKeys[rightKeyInsert] = currentSep;
        for (var i = idx; i < _order - 1; i++) {
          final dst = i - _minFill + 1;
          rKeys[dst] = lKeys[i];
          lKeys[i] = null;
        }

        final rightChildInsert = idx - _minFill + 1;
        for (var i = _minFill; i <= idx; i++) {
          final dst = i - _minFill;
          rChildren[dst] = lChildren[i];
          rCounts[dst] = lCounts[i];
          lChildren[i] = null;
          lCounts[i] = 0;
        }
        rChildren[rightChildInsert] = currentRight;
        rCounts[rightChildInsert] = currentRightCount;
        for (var i = idx + 1; i < _order; i++) {
          final dst = i - _minFill + 1;
          rChildren[dst] = lChildren[i];
          rCounts[dst] = lCounts[i];
          lChildren[i] = null;
          lCounts[i] = 0;
        }
      }

      node.count = _minFill;
      newRight.count = _order - _minFill + 1;

      var leftTotal = 0;
      for (var i = 0; i < _minFill; i++) {
        leftTotal += lCounts[i];
      }
      var rightTotal = 0;
      for (var i = 0; i < newRight.count; i++) {
        rightTotal += rCounts[i];
      }

      currentSep = promoted;
      currentRight = newRight;
      currentLeftCount = leftTotal;
      currentRightCount = rightTotal;
    }

    final newRoot = _InternalNode<K>();
    newRoot.keys[0] = currentSep;
    newRoot.children[0] = _root;
    newRoot.children[1] = currentRight;
    newRoot.counts[0] = currentLeftCount;
    newRoot.counts[1] = currentRightCount;
    newRoot.count = 2;
    _root = newRoot;
    _height++;
    _clearPath(depth);
  }

  void _deleteFound(L leaf, int idx) {
    leaf.removeAt(idx);
    _length--;
    if (_height > 1) {
      final depth = _height - 1;
      for (var level = 0; level < depth; level++) {
        _pathNodes[level]!.counts[_pathIndices[level]]--;
      }
      if (leaf.count < _minFill) {
        _rebalanceLeaf(leaf, depth);
      }
      _clearPath(depth);
    }
  }

  void _removeChildAt(_InternalNode<K> parent, int removedChildIdx) {
    final newCount = parent.count - 1;
    for (var i = removedChildIdx - 1; i < newCount - 1; i++) {
      parent.keys[i] = parent.keys[i + 1];
    }
    for (var i = removedChildIdx; i < newCount; i++) {
      parent.children[i] = parent.children[i + 1];
      parent.counts[i] = parent.counts[i + 1];
    }
    parent.keys[newCount - 1] = null;
    parent.children[newCount] = null;
    parent.counts[newCount] = 0;
    parent.count = newCount;
  }

  void _rebalanceLeaf(L leaf, int depth) {
    final parent = _pathNodes[depth - 1]!;
    final childIdx = _pathIndices[depth - 1];

    if (childIdx > 0) {
      final left = parent.children[childIdx - 1] as L;
      if (left.count > _minFill) {
        leaf.borrowFromLeft(left);
        parent.keys[childIdx - 1] = leaf.keys[0];
        parent.counts[childIdx - 1]--;
        parent.counts[childIdx]++;
        return;
      }

      left.mergeWithRight(leaf);
      if (identical(leaf, _tail)) {
        _tail = left;
      }
      parent.counts[childIdx - 1] += parent.counts[childIdx];
      _removeChildAt(parent, childIdx);
      _rebalanceInternal(depth - 1);
      return;
    }

    final right = parent.children[1] as L;
    if (right.count > _minFill) {
      leaf.borrowFromRight(right);
      parent.keys[0] = right.keys[0];
      parent.counts[0]++;
      parent.counts[1]--;
      return;
    }

    leaf.mergeWithRight(right);
    if (identical(right, _tail)) {
      _tail = leaf;
    }
    parent.counts[0] += parent.counts[1];
    _removeChildAt(parent, 1);
    _rebalanceInternal(depth - 1);
  }

  void _rebalanceInternal(int startLevel) {
    for (var level = startLevel; level >= 0; level--) {
      final node = _pathNodes[level]!;
      if (level == 0) {
        if (node.count == 1) {
          _root = node.children[0]!;
          node.children[0] = null;
          node.counts[0] = 0;
          _height--;
        }
        return;
      }

      if (node.count >= _minFill) {
        return;
      }

      final parent = _pathNodes[level - 1]!;
      final childIdx = _pathIndices[level - 1];

      if (childIdx > 0) {
        final left = parent.children[childIdx - 1] as _InternalNode<K>;
        if (left.count > _minFill) {
          final leftLast = left.count - 1;
          final movedChild = left.children[leftLast]!;
          final movedCount = left.counts[leftLast];
          final movedKey = left.keys[leftLast - 1] as K;

          for (var i = node.count - 1; i > 0; i--) {
            node.keys[i] = node.keys[i - 1];
          }
          for (var i = node.count; i > 0; i--) {
            node.children[i] = node.children[i - 1];
            node.counts[i] = node.counts[i - 1];
          }
          node.keys[0] = parent.keys[childIdx - 1];
          node.children[0] = movedChild;
          node.counts[0] = movedCount;
          node.count++;

          parent.keys[childIdx - 1] = movedKey;
          parent.counts[childIdx - 1] -= movedCount;
          parent.counts[childIdx] += movedCount;

          left.keys[leftLast - 1] = null;
          left.children[leftLast] = null;
          left.counts[leftLast] = 0;
          left.count = leftLast;
          return;
        }

        final leftCount = left.count;
        final nodeCount = node.count;
        left.keys[leftCount - 1] = parent.keys[childIdx - 1];
        for (var i = 0; i < nodeCount - 1; i++) {
          left.keys[leftCount + i] = node.keys[i];
          node.keys[i] = null;
        }
        for (var i = 0; i < nodeCount; i++) {
          left.children[leftCount + i] = node.children[i];
          left.counts[leftCount + i] = node.counts[i];
          node.children[i] = null;
          node.counts[i] = 0;
        }
        left.count = leftCount + nodeCount;
        node.count = 0;

        parent.counts[childIdx - 1] += parent.counts[childIdx];
        _removeChildAt(parent, childIdx);
        continue;
      }

      final right = parent.children[1] as _InternalNode<K>;
      if (right.count > _minFill) {
        final movedChild = right.children[0]!;
        final movedCount = right.counts[0];
        final movedKey = right.keys[0] as K;

        node.keys[node.count - 1] = parent.keys[0];
        node.children[node.count] = movedChild;
        node.counts[node.count] = movedCount;
        node.count++;

        parent.keys[0] = movedKey;
        parent.counts[0] += movedCount;
        parent.counts[1] -= movedCount;

        final newRightCount = right.count - 1;
        for (var i = 0; i < newRightCount - 1; i++) {
          right.keys[i] = right.keys[i + 1];
        }
        for (var i = 0; i < newRightCount; i++) {
          right.children[i] = right.children[i + 1];
          right.counts[i] = right.counts[i + 1];
        }
        right.keys[newRightCount - 1] = null;
        right.children[newRightCount] = null;
        right.counts[newRightCount] = 0;
        right.count = newRightCount;
        return;
      }

      final nodeCount = node.count;
      final rightCount = right.count;
      node.keys[nodeCount - 1] = parent.keys[0];
      for (var i = 0; i < rightCount - 1; i++) {
        node.keys[nodeCount + i] = right.keys[i];
        right.keys[i] = null;
      }
      for (var i = 0; i < rightCount; i++) {
        node.children[nodeCount + i] = right.children[i];
        node.counts[nodeCount + i] = right.counts[i];
        right.children[i] = null;
        right.counts[i] = 0;
      }
      node.count = nodeCount + rightCount;
      right.count = 0;

      parent.counts[0] += parent.counts[1];
      _removeChildAt(parent, 1);
    }
  }

  /// Verifies all B+ tree structural, ordering, link, and count invariants.
  @visibleForTesting
  void debugVerifyInvariants() {
    if (_length == 0) {
      if (_height != 1) {
        throw StateError('Empty tree must have height 1, got $_height');
      }
      if (!identical(_root, _head) || !identical(_root, _tail)) {
        throw StateError('Empty tree root/head/tail mismatch');
      }
      if (_head.count != 0 || _head.next != null) {
        throw StateError('Empty root leaf is not clean');
      }
      return;
    }

    final visitedLeaves = <L>[];
    final (totalCount, minKey, _) = _verifySubtree(_root, 1, visitedLeaves);
    if (totalCount != _length) {
      throw StateError(
        'Length mismatch: expected $_length, counted $totalCount',
      );
    }

    // Verify leaf linked list matches DFS leaf order and global key order.
    var cursor = _head;
    var index = 0;
    K? prevKey;
    while (true) {
      if (index >= visitedLeaves.length ||
          !identical(cursor, visitedLeaves[index])) {
        throw StateError('Leaf chain diverges at index $index');
      }
      for (var i = 0; i < cursor.count; i++) {
        final key = cursor.keys[i] as K;
        if (prevKey != null && _comparator(prevKey, key) >= 0) {
          throw StateError('Keys out of strict order: $prevKey >= $key');
        }
        prevKey = key;
      }
      index++;
      final nextLeaf = cursor.next as L?;
      if (nextLeaf == null) {
        if (!identical(cursor, _tail)) {
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
    if (minKey == null && _length > 0) {
      throw StateError('Missing minimum key in non-empty tree');
    }
  }

  (int, K?, K?) _verifySubtree(Object node, int depth, List<L> leaves) {
    if (node is _InternalNode<K>) {
      if (depth >= _height) {
        throw StateError('Internal node found at leaf depth $depth/$_height');
      }
      final minChildren = depth == 1 ? 2 : _minFill;
      if (node.count < minChildren || node.count > _order) {
        throw StateError(
          'Internal node count ${node.count} out of [$minChildren, $_order]',
        );
      }
      for (var i = node.count - 1; i < _order - 1; i++) {
        if (node.keys[i] != null) {
          throw StateError('Unclean separator key at $i');
        }
      }
      for (var i = node.count; i < _order; i++) {
        if (node.children[i] != null || node.counts[i] != 0) {
          throw StateError('Unclean child slot at $i');
        }
      }

      var total = 0;
      K? firstMin;
      K? prevMax;
      for (var i = 0; i < node.count; i++) {
        final child = node.children[i];
        if (child == null) {
          throw StateError('Null child at $i');
        }
        final (cCount, cMin, cMax) = _verifySubtree(child, depth + 1, leaves);
        if (cCount != node.counts[i]) {
          throw StateError(
            'Subtree count mismatch at $i: ${node.counts[i]} != $cCount',
          );
        }
        if (i == 0) {
          firstMin = cMin;
        } else {
          final sep = node.keys[i - 1] as K;
          if (_comparator(prevMax as K, sep) >= 0) {
            throw StateError('Left max $prevMax >= separator $sep');
          }
          if (_comparator(sep, cMin as K) > 0) {
            throw StateError('Separator $sep > right min $cMin');
          }
        }
        total += cCount;
        prevMax = cMax;
      }
      return (total, firstMin, prevMax);
    }

    if (depth != _height) {
      throw StateError('Leaf depth $depth != height $_height');
    }
    final leaf = node as L;
    final isRoot = _height == 1;
    final isTail = identical(leaf, _tail);
    final minEntries = isRoot ? 1 : (isTail ? 1 : _minFill);
    if (leaf.count < minEntries || leaf.count > _order) {
      throw StateError(
        'Leaf count ${leaf.count} out of [$minEntries, $_order]',
      );
    }
    for (var i = leaf.count; i < _order; i++) {
      if (leaf.keys[i] != null) {
        throw StateError('Unclean leaf key slot at $i');
      }
      if (leaf is _ValueLeaf<K, dynamic> && leaf.values[i] != null) {
        throw StateError('Unclean leaf value slot at $i');
      }
    }
    leaves.add(leaf);
    return (leaf.count, leaf.keys[0] as K, leaf.keys[leaf.count - 1] as K);
  }
}

/// Not part of public API
class BPlusTree<K, V> extends _BPlusTreeBase<K, _ValueLeaf<K, V>> {
  /// Not part of public API
  BPlusTree(super.comparator);

  @override
  _ValueLeaf<K, V> _createLeaf() => _ValueLeaf<K, V>();

  /// Not part of public API
  Iterable<V> get values => _BPlusValueIterable<K, V>(this);

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  V? get(K key) {
    if (_length == 0) return null;
    final leaf = _findLeaf(key);
    final idx = _findInLeaf(leaf, key);
    return idx >= 0 ? leaf.values[idx] : null;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  V getAt(int index) {
    final (leaf, slot) = _locateAt(index);
    return leaf.values[slot] as V;
  }

  /// Not part of public API
  Iterable<V> valuesFromKey(K startKey) {
    if (_length == 0) return const Iterable.empty();
    final leaf = _findLeaf(startKey);
    final idx = _findInLeaf(leaf, startKey);
    if (idx < 0) return const Iterable.empty();
    return _BPlusValueSliceIterable<K, V>(leaf, idx);
  }

  /// Not part of public API
  V? insert(K key, V value) {
    final tail = _tail;
    final tailCount = tail.count;
    if (tailCount > 0 && _comparator(key, tail.keys[tailCount - 1] as K) > 0) {
      if (tailCount < _order) {
        tail.keys[tailCount] = key;
        tail.values[tailCount] = value;
        tail.count = tailCount + 1;
        _incrementRightSpine();
        _length++;
        return null;
      }

      final newTail = _ValueLeaf<K, V>()
        ..keys[0] = key
        ..values[0] = value
        ..count = 1;
      tail.next = newTail;
      _tail = newTail;
      _insertTailLeaf(key, newTail);
      _length++;
      return null;
    }

    _ensurePathCapacity();
    final leaf = _findLeafWithPath(key);
    final idx = _findInLeaf(leaf, key);
    if (idx >= 0) {
      final oldValue = leaf.values[idx];
      leaf.values[idx] = value;
      _clearPath(_height - 1);
      return oldValue;
    }

    final insertPos = -idx - 1;
    final count = leaf.count;
    if (count < _order) {
      final keys = leaf.keys;
      final values = leaf.values;
      for (var i = count; i > insertPos; i--) {
        keys[i] = keys[i - 1];
        values[i] = values[i - 1];
      }
      keys[insertPos] = key;
      values[insertPos] = value;
      leaf.count = count + 1;
      for (var level = 0; level < _height - 1; level++) {
        _pathNodes[level]!.counts[_pathIndices[level]]++;
      }
      _length++;
      _clearPath(_height - 1);
      return null;
    }

    final right = _ValueLeaf<K, V>();
    final lKeys = leaf.keys;
    final lValues = leaf.values;
    final rKeys = right.keys;
    final rValues = right.values;

    if (insertPos < _minFill) {
      for (var i = _minFill - 1; i < _order; i++) {
        final dst = i - (_minFill - 1);
        rKeys[dst] = lKeys[i];
        rValues[dst] = lValues[i];
        lKeys[i] = null;
        lValues[i] = null;
      }
      for (var i = _minFill - 1; i > insertPos; i--) {
        lKeys[i] = lKeys[i - 1];
        lValues[i] = lValues[i - 1];
      }
      lKeys[insertPos] = key;
      lValues[insertPos] = value;
    } else {
      final rightInsert = insertPos - _minFill;
      for (var i = _minFill; i < insertPos; i++) {
        final dst = i - _minFill;
        rKeys[dst] = lKeys[i];
        rValues[dst] = lValues[i];
        lKeys[i] = null;
        lValues[i] = null;
      }
      rKeys[rightInsert] = key;
      rValues[rightInsert] = value;
      for (var i = insertPos; i < _order; i++) {
        final dst = i - _minFill + 1;
        rKeys[dst] = lKeys[i];
        rValues[dst] = lValues[i];
        lKeys[i] = null;
        lValues[i] = null;
      }
    }

    leaf.count = _minFill;
    right.count = _order - _minFill + 1;
    right.next = leaf.next;
    leaf.next = right;
    if (identical(leaf, _tail)) {
      _tail = right;
    }

    _propagateSplitUp(
      _height - 1,
      right.keys[0] as K,
      right,
      _minFill,
      right.count,
    );
    _length++;
    return null;
  }

  /// Not part of public API
  V? delete(K key) {
    if (_length == 0) return null;
    final leaf = _findLeafWithPath(key);
    final idx = _findInLeaf(leaf, key);
    if (idx < 0) {
      _clearPath(_height - 1);
      return null;
    }

    final oldValue = leaf.values[idx];
    _deleteFound(leaf, idx);
    return oldValue;
  }
}

/// Not part of public API
class PackedLazyBPlusTree<K> extends _BPlusTreeBase<K, _LazyLeaf<K>> {
  /// Not part of public API
  PackedLazyBPlusTree(super.comparator);

  @override
  _LazyLeaf<K> _createLeaf() => _LazyLeaf<K>();

  /// Not part of public API
  Iterable<Frame> get frames => _PackedLazyFrameIterable<K>(this);

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame _buildFrame(_LazyLeaf<K> leaf, int idx) {
    final rawLength = leaf.lengths[idx];
    return Frame.lazy(
      leaf.keys[idx] as Object,
      offset: leaf.offsets[idx].toInt(),
      length: rawLength == _nullLength ? null : rawLength,
    );
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame? get(K key) {
    if (_length == 0) return null;
    final leaf = _findLeaf(key);
    final idx = _findInLeaf(leaf, key);
    return idx >= 0 ? _buildFrame(leaf, idx) : null;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame getAt(int index) {
    final (leaf, slot) = _locateAt(index);
    return _buildFrame(leaf, slot);
  }

  /// Not part of public API
  Iterable<Frame> framesFromKey(K startKey) {
    if (_length == 0) return const Iterable.empty();
    final leaf = _findLeaf(startKey);
    final idx = _findInLeaf(leaf, startKey);
    if (idx < 0) return const Iterable.empty();
    return _PackedLazyFrameSliceIterable<K>(leaf, idx);
  }

  /// Not part of public API
  Frame? insertLazy(K key, int offset, int? length) {
    final encodedLength = length ?? _nullLength;
    final tail = _tail;
    final tailCount = tail.count;
    if (tailCount > 0 && _comparator(key, tail.keys[tailCount - 1] as K) > 0) {
      if (tailCount < _order) {
        tail.keys[tailCount] = key;
        tail.offsets[tailCount] = offset.toDouble();
        tail.lengths[tailCount] = encodedLength;
        tail.count = tailCount + 1;
        _incrementRightSpine();
        _length++;
        return null;
      }

      final newTail = _LazyLeaf<K>()
        ..keys[0] = key
        ..offsets[0] = offset.toDouble()
        ..lengths[0] = encodedLength
        ..count = 1;
      tail.next = newTail;
      _tail = newTail;
      _insertTailLeaf(key, newTail);
      _length++;
      return null;
    }

    _ensurePathCapacity();
    final leaf = _findLeafWithPath(key);
    final idx = _findInLeaf(leaf, key);
    if (idx >= 0) {
      final oldFrame = _buildFrame(leaf, idx);
      leaf.offsets[idx] = offset.toDouble();
      leaf.lengths[idx] = encodedLength;
      _clearPath(_height - 1);
      return oldFrame;
    }

    final insertPos = -idx - 1;
    final count = leaf.count;
    if (count < _order) {
      final keys = leaf.keys;
      final offsets = leaf.offsets;
      final lengths = leaf.lengths;
      for (var i = count; i > insertPos; i--) {
        keys[i] = keys[i - 1];
        offsets[i] = offsets[i - 1];
        lengths[i] = lengths[i - 1];
      }
      keys[insertPos] = key;
      offsets[insertPos] = offset.toDouble();
      lengths[insertPos] = encodedLength;
      leaf.count = count + 1;
      for (var level = 0; level < _height - 1; level++) {
        _pathNodes[level]!.counts[_pathIndices[level]]++;
      }
      _length++;
      _clearPath(_height - 1);
      return null;
    }

    final right = _LazyLeaf<K>();
    final lKeys = leaf.keys;
    final lOffsets = leaf.offsets;
    final lLengths = leaf.lengths;
    final rKeys = right.keys;
    final rOffsets = right.offsets;
    final rLengths = right.lengths;

    if (insertPos < _minFill) {
      for (var i = _minFill - 1; i < _order; i++) {
        final dst = i - (_minFill - 1);
        rKeys[dst] = lKeys[i];
        rOffsets[dst] = lOffsets[i];
        rLengths[dst] = lLengths[i];
        lKeys[i] = null;
      }
      for (var i = _minFill - 1; i > insertPos; i--) {
        lKeys[i] = lKeys[i - 1];
        lOffsets[i] = lOffsets[i - 1];
        lLengths[i] = lLengths[i - 1];
      }
      lKeys[insertPos] = key;
      lOffsets[insertPos] = offset.toDouble();
      lLengths[insertPos] = encodedLength;
    } else {
      final rightInsert = insertPos - _minFill;
      for (var i = _minFill; i < insertPos; i++) {
        final dst = i - _minFill;
        rKeys[dst] = lKeys[i];
        rOffsets[dst] = lOffsets[i];
        rLengths[dst] = lLengths[i];
        lKeys[i] = null;
      }
      rKeys[rightInsert] = key;
      rOffsets[rightInsert] = offset.toDouble();
      rLengths[rightInsert] = encodedLength;
      for (var i = insertPos; i < _order; i++) {
        final dst = i - _minFill + 1;
        rKeys[dst] = lKeys[i];
        rOffsets[dst] = lOffsets[i];
        rLengths[dst] = lLengths[i];
        lKeys[i] = null;
      }
    }

    leaf.count = _minFill;
    right.count = _order - _minFill + 1;
    right.next = leaf.next;
    leaf.next = right;
    if (identical(leaf, _tail)) {
      _tail = right;
    }

    _propagateSplitUp(
      _height - 1,
      right.keys[0] as K,
      right,
      _minFill,
      right.count,
    );
    _length++;
    return null;
  }

  /// Not part of public API
  Frame? deleteLazy(K key) {
    if (_length == 0) return null;
    final leaf = _findLeafWithPath(key);
    final idx = _findInLeaf(leaf, key);
    if (idx < 0) {
      _clearPath(_height - 1);
      return null;
    }

    final oldFrame = _buildFrame(leaf, idx);
    _deleteFound(leaf, idx);
    return oldFrame;
  }

  /// Not part of public API
  void updateOffsetAndLength(K key, int offset, int? length) {
    if (_length == 0) return;
    final leaf = _findLeaf(key);
    final idx = _findInLeaf(leaf, key);
    if (idx >= 0) {
      leaf.offsets[idx] = offset.toDouble();
      leaf.lengths[idx] = length ?? _nullLength;
    }
  }
}

abstract class _LeafCursorIterator<K, L extends _BPlusLeafBase<K>, E>
    implements Iterator<E> {
  L? _nextLeaf;
  int _nextIndex;
  L? _currentLeaf;
  var _currentIndex = 0;

  _LeafCursorIterator(this._nextLeaf, this._nextIndex);

  @override
  bool moveNext() {
    var leaf = _nextLeaf;
    var idx = _nextIndex;
    while (leaf != null && idx >= leaf.count) {
      leaf = leaf.next as L?;
      idx = 0;
    }
    if (leaf == null) {
      _currentLeaf = null;
      _nextLeaf = null;
      return false;
    }
    _currentLeaf = leaf;
    _currentIndex = idx;
    _nextLeaf = leaf;
    _nextIndex = idx + 1;
    return true;
  }
}

class _BPlusKeyIterator<K, L extends _BPlusLeafBase<K>>
    extends _LeafCursorIterator<K, L, K> {
  _BPlusKeyIterator(super.firstLeaf, super.startIndex);

  @override
  K get current {
    final leaf = _currentLeaf;
    if (leaf == null) throw StateError('No current element');
    return leaf.keys[_currentIndex] as K;
  }
}

@immutable
class _BPlusKeyIterable<K, L extends _BPlusLeafBase<K>>
    extends IterableBase<K> {
  final _BPlusTreeBase<K, L> _tree;

  const _BPlusKeyIterable(this._tree);

  @override
  int get length => _tree._length;

  @override
  bool get isEmpty => _tree._length == 0;

  @override
  bool get isNotEmpty => _tree._length > 0;

  @override
  Iterator<K> get iterator => _BPlusKeyIterator<K, L>(_tree._head, 0);
}

class _BPlusValueIterator<K, V>
    extends _LeafCursorIterator<K, _ValueLeaf<K, V>, V> {
  _BPlusValueIterator(super.firstLeaf, super.startIndex);

  @override
  V get current {
    final leaf = _currentLeaf;
    if (leaf == null) throw StateError('No current element');
    return leaf.values[_currentIndex] as V;
  }
}

@immutable
class _BPlusValueIterable<K, V> extends IterableBase<V> {
  final BPlusTree<K, V> _tree;

  const _BPlusValueIterable(this._tree);

  @override
  int get length => _tree._length;

  @override
  bool get isEmpty => _tree._length == 0;

  @override
  bool get isNotEmpty => _tree._length > 0;

  @override
  Iterator<V> get iterator => _BPlusValueIterator<K, V>(_tree._head, 0);
}

@immutable
class _BPlusValueSliceIterable<K, V> extends IterableBase<V> {
  final _ValueLeaf<K, V> _startLeaf;
  final int _startIndex;

  const _BPlusValueSliceIterable(this._startLeaf, this._startIndex);

  @override
  Iterator<V> get iterator => _BPlusValueIterator<K, V>(
        _startLeaf,
        _startIndex,
      );
}

class _PackedLazyFrameIterator<K>
    extends _LeafCursorIterator<K, _LazyLeaf<K>, Frame> {
  Frame? _currentFrame;

  _PackedLazyFrameIterator(super.firstLeaf, super.startIndex);

  @override
  bool moveNext() {
    if (!super.moveNext()) {
      _currentFrame = null;
      return false;
    }
    final leaf = _currentLeaf!;
    final idx = _currentIndex;
    final rawLength = leaf.lengths[idx];
    _currentFrame = Frame.lazy(
      leaf.keys[idx] as Object,
      offset: leaf.offsets[idx].toInt(),
      length: rawLength == _nullLength ? null : rawLength,
    );
    return true;
  }

  @override
  Frame get current =>
      _currentFrame ?? (throw StateError('No current element'));
}

@immutable
class _PackedLazyFrameIterable<K> extends IterableBase<Frame> {
  final PackedLazyBPlusTree<K> _tree;

  const _PackedLazyFrameIterable(this._tree);

  @override
  int get length => _tree._length;

  @override
  bool get isEmpty => _tree._length == 0;

  @override
  bool get isNotEmpty => _tree._length > 0;

  @override
  Iterator<Frame> get iterator => _PackedLazyFrameIterator<K>(_tree._head, 0);
}

@immutable
class _PackedLazyFrameSliceIterable<K> extends IterableBase<Frame> {
  final _LazyLeaf<K> _startLeaf;
  final int _startIndex;

  const _PackedLazyFrameSliceIterable(this._startLeaf, this._startIndex);

  @override
  Iterator<Frame> get iterator => _PackedLazyFrameIterator<K>(
        _startLeaf,
        _startIndex,
      );
}
