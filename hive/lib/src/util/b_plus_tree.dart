import 'dart:collection';
import 'dart:typed_data';

import 'package:meta/meta.dart';

const _capacity = 64;
const _maxEntries = 63;
const _minFill = 32;
const _maxHeight = 16;

final class _InternalNode<K> {
  final keys = List<K?>.filled(_capacity - 1, null);
  final children = List<Object?>.filled(_capacity, null);
  final counts = Int32List(_capacity);
  var count = 0;
}

final class _LeafNode<K, V> {
  final keys = List<K?>.filled(_capacity, null);
  final values = List<V?>.filled(_capacity, null);
  var count = 0;
  _LeafNode<K, V>? next;

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

  void borrowFromLeft(_LeafNode<K, V> left) {
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

  void borrowFromRight(_LeafNode<K, V> right) {
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

  void mergeWithRight(_LeafNode<K, V> right) {
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

/// Not part of public API
class BPlusTree<K, V> {
  final Comparator<K> _comparator;

  Object _root;
  _LeafNode<K, V> _head;
  _LeafNode<K, V> _tail;
  var _height = 1;
  var _length = 0;

  final _pathNodes = List<_InternalNode<K>?>.filled(_maxHeight, null);
  final _pathIndices = Int32List(_maxHeight);

  BPlusTree._(this._comparator, _LeafNode<K, V> leaf)
      : _root = leaf,
        _head = leaf,
        _tail = leaf;

  /// Not part of public API
  factory BPlusTree(Comparator<K> comparator) => BPlusTree._(
        comparator,
        _LeafNode<K, V>(),
      );

  /// Not part of public API
  int get length => _length;

  /// Not part of public API
  bool get isEmpty => _length == 0;

  /// Not part of public API
  bool get isNotEmpty => _length > 0;

  /// Not part of public API
  Iterable<K> get keys => _BPlusKeyIterable<K, V>(this);

  /// Not part of public API
  Iterable<V> get values => _BPlusValueIterable<K, V>(this);

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
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  K getKeyAt(int index) {
    final (leaf, slot) = _locateAt(index);
    return leaf.keys[slot] as K;
  }

  /// Not part of public API
  Iterable<V> valuesFromKey(K startKey) {
    if (_length == 0) return const Iterable.empty();
    final leaf = _findLeaf(startKey);
    final idx = _findInLeaf(leaf, startKey);
    if (idx < 0) return const Iterable.empty();
    return _valuesFrom(leaf, idx);
  }

  Iterable<V> _valuesFrom(_LeafNode<K, V>? startLeaf, int startIndex) sync* {
    var leaf = startLeaf;
    var idx = startIndex;
    while (leaf != null) {
      final count = leaf.count;
      final values = leaf.values;
      while (idx < count) {
        yield values[idx] as V;
        idx++;
      }
      leaf = leaf.next;
      idx = 0;
    }
  }

  /// Not part of public API
  V? insert(K key, V value) {
    final tail = _tail;
    final tailCount = tail.count;
    if (tailCount > 0 && _comparator(key, tail.keys[tailCount - 1] as K) > 0) {
      if (tailCount < _maxEntries) {
        tail.keys[tailCount] = key;
        tail.values[tailCount] = value;
        tail.count = tailCount + 1;
        _incrementRightSpine();
        _length++;
        return null;
      }

      final newTail = _LeafNode<K, V>()
        ..keys[0] = key
        ..values[0] = value
        ..count = 1;
      tail.next = newTail;
      _tail = newTail;
      _insertTailLeaf(key, newTail);
      _length++;
      return null;
    }

    final depth = _height - 1;
    final leaf = _findLeafWithPath(key);
    final pos = _findInLeaf(leaf, key);
    if (pos >= 0) {
      final oldValue = leaf.values[pos];
      leaf.values[pos] = value;
      _clearPath(depth);
      return oldValue;
    }

    final insertIdx = -pos - 1;
    final count = leaf.count;
    final keys = leaf.keys;
    final values = leaf.values;
    for (var i = count; i > insertIdx; i--) {
      keys[i] = keys[i - 1];
      values[i] = values[i - 1];
    }
    keys[insertIdx] = key;
    values[insertIdx] = value;
    leaf.count = count + 1;

    if (leaf.count < _capacity) {
      for (var level = 0; level < depth; level++) {
        final internal = _pathNodes[level] as _InternalNode<K>;
        internal.counts[_pathIndices[level]]++;
      }
      _clearPath(depth);
      _length++;
      return null;
    }

    // Leaf transiently has _capacity (64) entries; split evenly into 32 + 32.
    final newRight = _LeafNode<K, V>();
    final rKeys = newRight.keys;
    final rValues = newRight.values;
    for (var i = _minFill; i < _capacity; i++) {
      final dst = i - _minFill;
      rKeys[dst] = keys[i];
      rValues[dst] = values[i];
      keys[i] = null;
      values[i] = null;
    }
    leaf.count = _minFill;
    newRight.count = _minFill;
    newRight.next = leaf.next;
    leaf.next = newRight;
    if (identical(leaf, _tail)) {
      _tail = newRight;
    }

    _propagateSplitUp(
      depth,
      rKeys[0] as K,
      newRight,
      _minFill,
      _minFill,
    );
    _length++;
    return null;
  }

  /// Not part of public API
  V? delete(K key) {
    if (_length == 0) return null;

    final depth = _height - 1;
    final leaf = _findLeafWithPath(key);
    final idx = _findInLeaf(leaf, key);
    if (idx < 0) {
      _clearPath(depth);
      return null;
    }

    final oldValue = leaf.values[idx];
    leaf.removeAt(idx);
    _length--;

    if (depth > 0) {
      for (var level = 0; level < depth; level++) {
        final internal = _pathNodes[level] as _InternalNode<K>;
        internal.counts[_pathIndices[level]]--;
      }
      if (leaf.count < _minFill) {
        _rebalanceLeaf(leaf, depth);
      }
      _clearPath(depth);
    }

    return oldValue;
  }

  /// Not part of public API
  void clear() {
    final leaf = _LeafNode<K, V>();
    _root = leaf;
    _head = leaf;
    _tail = leaf;
    _height = 1;
    _length = 0;
  }

  int _findChildIndex(_InternalNode<K> node, K key) {
    final keys = node.keys;
    var lo = 0;
    var hi = node.count - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_comparator(key, keys[mid] as K) < 0) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  int _findInLeaf(_LeafNode<K, V> leaf, K key) {
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

  _LeafNode<K, V> _findLeaf(K key) {
    var node = _root;
    for (var level = 0; level < _height - 1; level++) {
      final internal = node as _InternalNode<K>;
      node = internal.children[_findChildIndex(internal, key)] as Object;
    }
    return node as _LeafNode<K, V>;
  }

  _LeafNode<K, V> _findLeafWithPath(K key) {
    var node = _root;
    for (var level = 0; level < _height - 1; level++) {
      final internal = node as _InternalNode<K>;
      final childIdx = _findChildIndex(internal, key);
      _pathNodes[level] = internal;
      _pathIndices[level] = childIdx;
      node = internal.children[childIdx] as Object;
    }
    return node as _LeafNode<K, V>;
  }

  (_LeafNode<K, V>, int) _locateAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', _length);
    var remaining = index;
    var node = _root;
    for (var level = 0; level < _height - 1; level++) {
      final internal = node as _InternalNode<K>;
      final counts = internal.counts;
      final count = internal.count;
      var i = 0;
      while (i < count - 1) {
        final c = counts[i];
        if (remaining < c) break;
        remaining -= c;
        i++;
      }
      node = internal.children[i] as Object;
    }
    return (node as _LeafNode<K, V>, remaining);
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
      node = internal.children[last] as Object;
    }
  }

  void _insertTailLeaf(K sepKey, _LeafNode<K, V> newTail) {
    var node = _root;
    final depth = _height - 1;
    for (var level = 0; level < depth; level++) {
      final internal = node as _InternalNode<K>;
      final last = internal.count - 1;
      _pathNodes[level] = internal;
      _pathIndices[level] = last;
      node = internal.children[last] as Object;
    }
    _propagateSplitUp(depth, sepKey, newTail, _maxEntries, 1);
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
      final node = _pathNodes[level] as _InternalNode<K>;
      final idx = _pathIndices[level];
      final keys = node.keys;
      final children = node.children;
      final counts = node.counts;

      counts[idx] = currentLeftCount;

      final insertChildPos = idx + 1;
      for (var i = node.count - 1; i > idx; i--) {
        keys[i] = keys[i - 1];
      }
      for (var i = node.count; i > insertChildPos; i--) {
        children[i] = children[i - 1];
        counts[i] = counts[i - 1];
      }
      keys[idx] = currentSep;
      children[insertChildPos] = currentRight;
      counts[insertChildPos] = currentRightCount;
      node.count++;

      if (node.count < _capacity) {
        for (var up = level - 1; up >= 0; up--) {
          final ancestor = _pathNodes[up] as _InternalNode<K>;
          ancestor.counts[_pathIndices[up]]++;
        }
        _clearPath(depth);
        return;
      }

      // Internal node transiently has _capacity (64) children; split 32 + 32.
      final promoted = keys[_minFill - 1] as K;
      keys[_minFill - 1] = null;

      final newRight = _InternalNode<K>();
      final rKeys = newRight.keys;
      final rChildren = newRight.children;
      final rCounts = newRight.counts;

      for (var i = _minFill; i < _capacity - 1; i++) {
        rKeys[i - _minFill] = keys[i];
        keys[i] = null;
      }

      var rightTotal = 0;
      for (var i = _minFill; i < _capacity; i++) {
        final dst = i - _minFill;
        rChildren[dst] = children[i];
        final childCount = counts[i];
        rCounts[dst] = childCount;
        rightTotal += childCount;
        children[i] = null;
        counts[i] = 0;
      }

      var leftTotal = 0;
      for (var i = 0; i < _minFill; i++) {
        leftTotal += counts[i];
      }

      node.count = _minFill;
      newRight.count = _minFill;

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

  void _removeChildAt(_InternalNode<K> parent, int removedChildIdx) {
    final newCount = parent.count - 1;
    final keys = parent.keys;
    final children = parent.children;
    final counts = parent.counts;
    for (var i = removedChildIdx - 1; i < newCount - 1; i++) {
      keys[i] = keys[i + 1];
    }
    for (var i = removedChildIdx; i < newCount; i++) {
      children[i] = children[i + 1];
      counts[i] = counts[i + 1];
    }
    keys[newCount - 1] = null;
    children[newCount] = null;
    counts[newCount] = 0;
    parent.count = newCount;
  }

  void _rebalanceLeaf(_LeafNode<K, V> leaf, int depth) {
    final parent = _pathNodes[depth - 1] as _InternalNode<K>;
    final childIdx = _pathIndices[depth - 1];

    if (childIdx > 0) {
      final left = parent.children[childIdx - 1] as _LeafNode<K, V>;
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

    final right = parent.children[1] as _LeafNode<K, V>;
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
      final node = _pathNodes[level] as _InternalNode<K>;
      if (level == 0) {
        if (node.count == 1) {
          _root = node.children[0] as Object;
          node.children[0] = null;
          node.counts[0] = 0;
          _height--;
        }
        return;
      }

      if (node.count >= _minFill) {
        return;
      }

      final parent = _pathNodes[level - 1] as _InternalNode<K>;
      final childIdx = _pathIndices[level - 1];

      if (childIdx > 0) {
        final left = parent.children[childIdx - 1] as _InternalNode<K>;
        if (left.count > _minFill) {
          final leftLast = left.count - 1;
          final movedChild = left.children[leftLast] as Object;
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
        final movedChild = right.children[0] as Object;
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

  // coverage:ignore-start
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
      for (var i = 0; i < _capacity; i++) {
        if (_head.keys[i] != null || _head.values[i] != null) {
          throw StateError('Unclean empty root slot at $i');
        }
      }
      return;
    }

    final visitedLeaves = <_LeafNode<K, V>>[];
    final (total, _, _) = _verifySubtree(_root, 1, visitedLeaves);
    if (total != _length) {
      throw StateError('Length mismatch: tree has $total, _length=$_length');
    }
    if (visitedLeaves.isEmpty ||
        !identical(visitedLeaves.first, _head) ||
        !identical(visitedLeaves.last, _tail)) {
      throw StateError('Head/tail pointers do not match tree edges');
    }

    _LeafNode<K, V>? cursor = _head;
    var index = 0;
    var hasPrev = false;
    K? prevKey;
    while (cursor != null) {
      if (index >= visitedLeaves.length ||
          !identical(cursor, visitedLeaves[index])) {
        throw StateError('Leaf chain mismatch at leaf $index');
      }
      for (var i = 0; i < cursor.count; i++) {
        final key = cursor.keys[i] as K;
        if (hasPrev && _comparator(prevKey as K, key) >= 0) {
          throw StateError('Out-of-order keys in leaves: $prevKey >= $key');
        }
        prevKey = key;
        hasPrev = true;
      }
      index++;
      final nextLeaf = cursor.next;
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
  }

  (int, K?, K?) _verifySubtree(
    Object node,
    int depth,
    List<_LeafNode<K, V>> leaves,
  ) {
    if (node is _InternalNode<K>) {
      if (depth >= _height) {
        throw StateError('Internal node found at leaf depth $depth/$_height');
      }
      final minChildren = depth == 1 ? 2 : _minFill;
      if (node.count < minChildren || node.count > _maxEntries) {
        throw StateError(
          'Internal node count ${node.count} out of [$minChildren, $_maxEntries]',
        );
      }
      for (var i = node.count - 1; i < _capacity - 1; i++) {
        if (node.keys[i] != null) {
          throw StateError('Unclean separator key at $i');
        }
      }
      for (var i = node.count; i < _capacity; i++) {
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
    final leaf = node as _LeafNode<K, V>;
    final isRoot = _height == 1;
    final isTail = identical(leaf, _tail);
    final minEntries = isRoot || isTail ? 1 : _minFill;
    if (leaf.count < minEntries || leaf.count > _maxEntries) {
      throw StateError(
        'Leaf count ${leaf.count} out of [$minEntries, $_maxEntries]',
      );
    }
    for (var i = leaf.count; i < _capacity; i++) {
      if (leaf.keys[i] != null || leaf.values[i] != null) {
        throw StateError('Unclean leaf slot at $i');
      }
    }
    leaves.add(leaf);
    return (leaf.count, leaf.keys[0] as K, leaf.keys[leaf.count - 1] as K);
  }
  // coverage:ignore-end
}

abstract class _LeafIterator<K, V, E> implements Iterator<E> {
  _LeafNode<K, V>? _nextLeaf;
  var _nextIndex = 0;
  _LeafNode<K, V>? _currentLeaf;
  var _currentIndex = 0;

  _LeafIterator(this._nextLeaf);

  @override
  bool moveNext() {
    var leaf = _nextLeaf;
    var idx = _nextIndex;
    while (leaf != null && idx >= leaf.count) {
      leaf = leaf.next;
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

class _BPlusKeyIterator<K, V> extends _LeafIterator<K, V, K> {
  _BPlusKeyIterator(super.firstLeaf);

  @override
  K get current {
    final leaf = _currentLeaf;
    if (leaf == null) throw StateError('No current element');
    return leaf.keys[_currentIndex] as K;
  }
}

@immutable
class _BPlusKeyIterable<K, V> extends IterableBase<K> {
  final BPlusTree<K, V> _tree;

  const _BPlusKeyIterable(this._tree);

  @override
  int get length => _tree._length;

  @override
  bool get isEmpty => _tree._length == 0;

  @override
  bool get isNotEmpty => _tree._length > 0;

  @override
  Iterator<K> get iterator => _BPlusKeyIterator<K, V>(_tree._head);
}

class _BPlusValueIterator<K, V> extends _LeafIterator<K, V, V> {
  _BPlusValueIterator(super.firstLeaf);

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
  Iterator<V> get iterator => _BPlusValueIterator<K, V>(_tree._head);
}
