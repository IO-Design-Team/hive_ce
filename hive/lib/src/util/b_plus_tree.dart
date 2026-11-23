import 'dart:collection';
import 'dart:typed_data';

import 'package:hive_ce/src/binary/frame.dart';
import 'package:meta/meta.dart';

const _capacity = 64;
const _maxEntries = 63;
const _minFill = 32;
const _maxHeight = 16;
const _nullLength = -1;

final class _InternalNode<K> {
  final keys = List<K?>.filled(_capacity - 1, null);
  final children = List<Object?>.filled(_capacity, null);
  final counts = Int32List(_capacity);
  var count = 0;
}

abstract class _BPlusLeafBase<K> {
  final keys = List<K?>.filled(_capacity, null);
  var count = 0;
  _BPlusLeafBase<K>? next;

  void mergeWithRight(covariant _BPlusLeafBase<K> right);
}

final class _ValueLeaf<K, V> extends _BPlusLeafBase<K> {
  final values = List<V?>.filled(_capacity, null);

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
  final offsets = Float64List(_capacity);
  final lengths = Int32List(_capacity);

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame frameAt(int index) {
    final rawLength = lengths[index];
    return Frame.lazy(
      keys[index] as Object,
      length: rawLength == _nullLength ? null : rawLength,
      offset: offsets[index].toInt(),
    );
  }

  void removeAt(int index) {
    final newCount = count - 1;
    for (var i = index; i < newCount; i++) {
      keys[i] = keys[i + 1];
      offsets[i] = offsets[i + 1];
      lengths[i] = lengths[i + 1];
    }
    keys[newCount] = null;
    offsets[newCount] = 0;
    lengths[newCount] = 0;
    count = newCount;
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
      right.offsets[i] = 0;
      right.lengths[i] = 0;
    }
    count = offset + rCount;
    right.count = 0;
    next = right.next;
    right.next = null;
  }
}

abstract class _BPlusTreeBase<K, L extends _BPlusLeafBase<K>> {
  final Comparator<K> _comparator;

  Object _root;
  L _head;
  L _tail;
  var _height = 1;
  var _length = 0;

  final _pathNodes = List<_InternalNode<K>?>.filled(_maxHeight, null);
  final _pathIndices = Int32List(_maxHeight);

  _BPlusTreeBase(this._comparator, L leaf)
      : _root = leaf,
        _head = leaf,
        _tail = leaf;

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

  L _findLeaf(K key) {
    var node = _root;
    for (var level = 0; level < _height - 1; level++) {
      final internal = node as _InternalNode<K>;
      node = internal.children[_findChildIndex(internal, key)] as Object;
    }
    return node as L;
  }

  L _findLeafWithPath(K key) {
    var node = _root;
    for (var level = 0; level < _height - 1; level++) {
      final internal = node as _InternalNode<K>;
      final childIdx = _findChildIndex(internal, key);
      _pathNodes[level] = internal;
      _pathIndices[level] = childIdx;
      node = internal.children[childIdx] as Object;
    }
    return node as L;
  }

  (L, int) _locateAt(int index) {
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
    return (node as L, remaining);
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

  void _insertTailLeaf(K sepKey, L newTail) {
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
      final (promoted, newRight, leftTotal, rightTotal) = _splitInternal(node);
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

  (K, _InternalNode<K>, int, int) _splitInternal(_InternalNode<K> left) {
    final keys = left.keys;
    final children = left.children;
    final counts = left.counts;

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

    left.count = _minFill;
    newRight.count = _minFill;
    return (promoted, newRight, leftTotal, rightTotal);
  }

  void _appendInternal(
    _InternalNode<K> left,
    K sepKey,
    _InternalNode<K> right,
  ) {
    final leftCount = left.count;
    final rightCount = right.count;
    left.keys[leftCount - 1] = sepKey;
    for (var i = 0; i < rightCount - 1; i++) {
      left.keys[leftCount + i] = right.keys[i];
      right.keys[i] = null;
    }
    for (var i = 0; i < rightCount; i++) {
      left.children[leftCount + i] = right.children[i];
      left.counts[leftCount + i] = right.counts[i];
      right.children[i] = null;
      right.counts[i] = 0;
    }
    left.count = leftCount + rightCount;
    right.count = 0;
  }

  void _afterDelete(L leaf) {
    _length--;
    final depth = _height - 1;
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

  void _rebalanceLeaf(L leaf, int depth) {
    final parent = _pathNodes[depth - 1] as _InternalNode<K>;
    final childIdx = _pathIndices[depth - 1];

    final int leftIdx;
    if (childIdx > 0 &&
        (parent.children[childIdx - 1] as L).count + leaf.count <=
            _maxEntries) {
      leftIdx = childIdx - 1;
    } else if (childIdx + 1 < parent.count &&
        leaf.count + (parent.children[childIdx + 1] as L).count <=
            _maxEntries) {
      leftIdx = childIdx;
    } else {
      return;
    }

    final leftLeaf = parent.children[leftIdx] as L;
    final rightLeaf = parent.children[leftIdx + 1] as L;
    leftLeaf.mergeWithRight(rightLeaf);
    if (identical(rightLeaf, _tail)) {
      _tail = leftLeaf;
    }
    parent.counts[leftIdx] += parent.counts[leftIdx + 1];
    _removeChildAt(parent, leftIdx + 1);
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

      int? leftIdx;
      if (childIdx > 0 &&
          (parent.children[childIdx - 1] as _InternalNode<K>).count +
                  node.count <=
              _maxEntries) {
        leftIdx = childIdx - 1;
      } else if (childIdx + 1 < parent.count &&
          node.count +
                  (parent.children[childIdx + 1] as _InternalNode<K>).count <=
              _maxEntries) {
        leftIdx = childIdx;
      }

      if (leftIdx != null) {
        final left = parent.children[leftIdx] as _InternalNode<K>;
        final right = parent.children[leftIdx + 1] as _InternalNode<K>;
        _appendInternal(left, parent.keys[leftIdx] as K, right);
        parent.counts[leftIdx] += parent.counts[leftIdx + 1];
        _removeChildAt(parent, leftIdx + 1);
        continue;
      }

      if (node.count == 1) {
        final idx = childIdx > 0 ? childIdx - 1 : 0;
        final left = parent.children[idx] as _InternalNode<K>;
        final right = parent.children[idx + 1] as _InternalNode<K>;
        _appendInternal(left, parent.keys[idx] as K, right);
        final (promoted, newRight, leftTotal, rightTotal) =
            _splitInternal(left);
        parent.keys[idx] = promoted;
        parent.children[idx + 1] = newRight;
        parent.counts[idx] = leftTotal;
        parent.counts[idx + 1] = rightTotal;
      }
      return;
    }
  }

  /// Not part of public API
  @visibleForTesting
  ({
    int height,
    int length,
    Object root,
    Object head,
    Object tail,
    ({
      bool isLeaf,
      int count,
      List<K?> keys,
      List<Object?>? children,
      List<int>? counts,
      List<Object?>? values,
      List<double>? offsets,
      List<int>? lengths,
      Object? next,
    })
        Function(Object node) inspect,
  }) debugSnapshot() => (
        height: _height,
        length: _length,
        root: _root,
        head: _head,
        tail: _tail,
        inspect: (node) {
          if (node is _InternalNode<K>) {
            return (
              isLeaf: false,
              count: node.count,
              keys: node.keys,
              children: node.children,
              counts: node.counts,
              values: null,
              offsets: null,
              lengths: null,
              next: null,
            );
          }
          final leaf = node as _BPlusLeafBase<K>;
          return (
            isLeaf: true,
            count: leaf.count,
            keys: leaf.keys,
            children: null,
            counts: null,
            values: leaf is _ValueLeaf<K, Object?> ? leaf.values : null,
            offsets: leaf is _LazyLeaf<K> ? leaf.offsets : null,
            lengths: leaf is _LazyLeaf<K> ? leaf.lengths : null,
            next: leaf.next,
          );
        },
      );
}

/// Not part of public API
class BPlusTree<K, V> extends _BPlusTreeBase<K, _ValueLeaf<K, V>> {
  /// Not part of public API
  BPlusTree(Comparator<K> comparator) : super(comparator, _ValueLeaf<K, V>());

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
    return _valuesFrom(leaf, idx);
  }

  Iterable<V> _valuesFrom(_ValueLeaf<K, V>? startLeaf, int startIndex) sync* {
    var leaf = startLeaf;
    var idx = startIndex;
    while (leaf != null) {
      final count = leaf.count;
      final values = leaf.values;
      while (idx < count) {
        yield values[idx] as V;
        idx++;
      }
      leaf = leaf.next as _ValueLeaf<K, V>?;
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
    final newRight = _ValueLeaf<K, V>();
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
    _afterDelete(leaf);
    return oldValue;
  }
}

/// Not part of public API
class PackedLazyBPlusTree<K> extends _BPlusTreeBase<K, _LazyLeaf<K>> {
  /// Not part of public API
  PackedLazyBPlusTree(Comparator<K> comparator)
      : super(comparator, _LazyLeaf<K>());

  @override
  _LazyLeaf<K> _createLeaf() => _LazyLeaf<K>();

  /// Not part of public API
  Iterable<Frame> get frames => _PackedLazyFrameIterable<K>(this);

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame? get(K key) {
    if (_length == 0) return null;
    final leaf = _findLeaf(key);
    final idx = _findInLeaf(leaf, key);
    return idx >= 0 ? leaf.frameAt(idx) : null;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame getAt(int index) {
    final (leaf, slot) = _locateAt(index);
    return leaf.frameAt(slot);
  }

  /// Not part of public API
  Iterable<Frame> framesFromKey(K startKey) {
    if (_length == 0) return const Iterable.empty();
    final leaf = _findLeaf(startKey);
    final idx = _findInLeaf(leaf, startKey);
    if (idx < 0) return const Iterable.empty();
    return _framesFrom(leaf, idx);
  }

  Iterable<Frame> _framesFrom(_LazyLeaf<K>? startLeaf, int startIndex) sync* {
    var leaf = startLeaf;
    var idx = startIndex;
    while (leaf != null) {
      final count = leaf.count;
      while (idx < count) {
        yield leaf.frameAt(idx);
        idx++;
      }
      leaf = leaf.next as _LazyLeaf<K>?;
      idx = 0;
    }
  }

  /// Not part of public API
  Frame? insertLazy(K key, int offset, int? length) {
    final offsetDouble = offset.toDouble();
    final rawLength = length ?? _nullLength;

    final tail = _tail;
    final tailCount = tail.count;
    if (tailCount > 0 && _comparator(key, tail.keys[tailCount - 1] as K) > 0) {
      if (tailCount < _maxEntries) {
        tail.keys[tailCount] = key;
        tail.offsets[tailCount] = offsetDouble;
        tail.lengths[tailCount] = rawLength;
        tail.count = tailCount + 1;
        _incrementRightSpine();
        _length++;
        return null;
      }

      final newTail = _LazyLeaf<K>()
        ..keys[0] = key
        ..offsets[0] = offsetDouble
        ..lengths[0] = rawLength
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
      final oldFrame = leaf.frameAt(pos);
      leaf.offsets[pos] = offsetDouble;
      leaf.lengths[pos] = rawLength;
      _clearPath(depth);
      return oldFrame;
    }

    final insertIdx = -pos - 1;
    final count = leaf.count;
    final keys = leaf.keys;
    final offsets = leaf.offsets;
    final lengths = leaf.lengths;
    for (var i = count; i > insertIdx; i--) {
      keys[i] = keys[i - 1];
      offsets[i] = offsets[i - 1];
      lengths[i] = lengths[i - 1];
    }
    keys[insertIdx] = key;
    offsets[insertIdx] = offsetDouble;
    lengths[insertIdx] = rawLength;
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
    final newRight = _LazyLeaf<K>();
    final rKeys = newRight.keys;
    final rOffsets = newRight.offsets;
    final rLengths = newRight.lengths;
    for (var i = _minFill; i < _capacity; i++) {
      final dst = i - _minFill;
      rKeys[dst] = keys[i];
      rOffsets[dst] = offsets[i];
      rLengths[dst] = lengths[i];
      keys[i] = null;
      offsets[i] = 0;
      lengths[i] = 0;
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
  Frame? deleteLazy(K key) {
    if (_length == 0) return null;

    final depth = _height - 1;
    final leaf = _findLeafWithPath(key);
    final idx = _findInLeaf(leaf, key);
    if (idx < 0) {
      _clearPath(depth);
      return null;
    }

    final oldFrame = leaf.frameAt(idx);
    leaf.removeAt(idx);
    _afterDelete(leaf);
    return oldFrame;
  }

  /// Not part of public API
  bool updateOffsetAndLength(K key, int offset, int? length) {
    if (_length == 0) return false;
    final leaf = _findLeaf(key);
    final idx = _findInLeaf(leaf, key);
    if (idx < 0) return false;
    leaf.offsets[idx] = offset.toDouble();
    leaf.lengths[idx] = length ?? _nullLength;
    return true;
  }

  /// Not part of public API
  void updateOffsets(Iterable<Frame> frames) {
    if (_length == 0) return;

    _LazyLeaf<K>? leaf = _head;
    var idx = 0;

    for (final frame in frames) {
      final key = frame.key as K;
      final newOffset = frame.offset.toDouble();
      final newLength = frame.length ?? _nullLength;

      while (leaf != null && idx >= leaf.count) {
        leaf = leaf.next as _LazyLeaf<K>?;
        idx = 0;
      }

      if (leaf != null) {
        final cmp = _comparator(leaf.keys[idx] as K, key);
        if (cmp == 0) {
          leaf.offsets[idx] = newOffset;
          leaf.lengths[idx] = newLength;
          idx++;
          continue;
        }
        if (cmp < 0) {
          while (leaf != null &&
              leaf.count > 0 &&
              _comparator(leaf.keys[leaf.count - 1] as K, key) < 0) {
            leaf = leaf.next as _LazyLeaf<K>?;
            idx = 0;
          }
          if (leaf != null) {
            final keys = leaf.keys;
            var lo = idx;
            var hi = leaf.count - 1;
            var found = -1;
            while (lo <= hi) {
              final mid = (lo + hi) >> 1;
              final midCmp = _comparator(key, keys[mid] as K);
              if (midCmp > 0) {
                lo = mid + 1;
              } else if (midCmp < 0) {
                hi = mid - 1;
              } else {
                found = mid;
                break;
              }
            }
            if (found >= 0) {
              leaf.offsets[found] = newOffset;
              leaf.lengths[found] = newLength;
              idx = found + 1;
            } else {
              idx = lo;
            }
          }
          continue;
        }
      }

      updateOffsetAndLength(key, frame.offset, frame.length);
    }
  }
}

abstract class _LeafCursorIterator<K, L extends _BPlusLeafBase<K>, E>
    implements Iterator<E> {
  L? _nextLeaf;
  var _nextIndex = 0;
  L? _currentLeaf;
  var _currentIndex = 0;

  _LeafCursorIterator(this._nextLeaf);

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
  _BPlusKeyIterator(super.firstLeaf);

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
  Iterator<K> get iterator => _BPlusKeyIterator<K, L>(_tree._head);
}

class _BPlusValueIterator<K, V>
    extends _LeafCursorIterator<K, _ValueLeaf<K, V>, V> {
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

class _PackedLazyFrameIterator<K>
    extends _LeafCursorIterator<K, _LazyLeaf<K>, Frame> {
  _PackedLazyFrameIterator(super.firstLeaf);

  @override
  Frame get current {
    final leaf = _currentLeaf;
    if (leaf == null) throw StateError('No current element');
    return leaf.frameAt(_currentIndex);
  }
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
  Iterator<Frame> get iterator => _PackedLazyFrameIterator<K>(_tree._head);
}
