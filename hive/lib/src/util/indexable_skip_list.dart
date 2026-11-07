import 'dart:collection';
import 'dart:math';
import 'package:meta/meta.dart';

/// Not part of public API
class IndexableSkipList<K, V> {
  static const _maxHeight = 32;

  final _Node<K, V> _head = _Node(
    null,
    null,
    List.filled(_maxHeight, null),
    List.filled(_maxHeight, 0),
  );

  final Random _random;

  /// The last node before the insert position on each level
  final _update = List<_Node<K, V>?>.filled(_maxHeight, null);

  /// The index of each node in [_update] plus one
  final _rank = List.filled(_maxHeight, 0);

  final Comparator<K> _comparator;

  var _height = 1;

  var _length = 0;

  /// Not part of public API
  IndexableSkipList(this._comparator, [Random? random])
      : _random = random ?? Random();

  /// Not part of public API
  int get length => _length;

  /// Not part of public API
  Iterable<K> get keys => _KeyIterable(_head);

  /// Not part of public API
  Iterable<V> get values => _ValueIterable(_head);

  /// Not part of public API
  V? insert(K key, V? value) {
    final update = _update;
    final rank = _rank;

    var current = _head;
    for (var level = _height - 1; level >= 0; level--) {
      var currentRank = level == _height - 1 ? 0 : rank[level + 1];
      while (true) {
        final next = current.next[level];
        if (next == null || _comparator(key, next.key as K) <= 0) break;
        currentRank += next.width[level];
        current = next;
      }
      update[level] = current;
      rank[level] = currentRank;
    }

    final existingNode = current.next[0];
    if (existingNode != null && _comparator(key, existingNode.key as K) == 0) {
      final oldValue = existingNode.value;
      existingNode.value = value;
      return oldValue;
    }

    // calculate this new node's level
    var newLevel = 0;
    while (_random.nextBool() && newLevel < _maxHeight - 1) {
      newLevel++;
    }
    if (newLevel >= _height) {
      newLevel = _height++;
      update[newLevel] = _head;
      rank[newLevel] = 0;
    }

    final newNode = _Node<K, V>(
      key,
      value,
      List.filled(newLevel + 1, null),
      List.filled(newLevel + 1, 0),
    );

    final newRank = rank[0] + 1;
    for (var level = 0; level <= newLevel; level++) {
      final prev = update[level]!;
      final next = prev.next[level];
      final width = newRank - rank[level];
      newNode.width[level] = width;
      newNode.next[level] = next;
      prev.next[level] = newNode;
      if (next != null) {
        next.width[level] -= width - 1;
      }
    }

    for (var level = newLevel + 1; level < _height; level++) {
      final next = update[level]!.next[level];
      if (next != null) {
        next.width[level]++;
      }
    }

    _length++;
    return null;
  }

  /// Not part of public API
  V? delete(K key) {
    final node = _getNode(key);
    if (node == null) return null;

    var current = _head;
    // Next & Down
    for (var level = _height - 1; level >= 0; level--) {
      while (true) {
        final next = current.next[level];
        if (next == null || _comparator(key, next.key as K) <= 0) break;
        current = next;
      }

      if (level > node.level) {
        final next = current.next[level];
        if (next != null) {
          next.width[level]--;
        }
      } else {
        final next = node.next[level];
        current.next[level] = next;
        if (next != null) {
          next.width[level] += node.width[level] - 1;
        }
      }
    }

    if (node.level == _height - 1 &&
        _height > 1 &&
        _head.next[node.level] == null) {
      _height--;
    }

    _length--;
    return node.value;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  V? get(K key) => _getNode(key)?.value;

  /// Not part of public API
  // TODO: write test
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Iterable<V> valuesFromKey(K key) {
    final node = _getNode(key);
    final virtualHead = _Node(null, null, [node], [0]);
    return _ValueIterable(virtualHead);
  }

  _Node<K, V>? _getNode(K key) {
    var prev = _head;
    _Node<K, V>? node;
    for (var i = _height - 1; i >= 0; i--) {
      node = prev.next[i];

      while (node != null && _comparator(key, node.key as K) > 0) {
        prev = node;
        node = node.next[i];
      }
    }

    if (node != null && _comparator(key, node.key as K) == 0) {
      return node;
    }
    return null;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  V? getAt(int index) => _getNodeAt(index).value;

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  K? getKeyAt(int index) => _getNodeAt(index).key;

  _Node<K, V> _getNodeAt(int index) {
    RangeError.checkValidIndex(index, this);

    var prev = _head;
    _Node<K, V>? node;
    for (var level = _height - 1; level >= 0; level--) {
      node = prev.next[level];

      while (node != null && index >= node.width[level]) {
        index -= node.width[level];
        prev = node;
        node = node.next[level];
      }
    }

    if (node == null) {
      throw StateError('Skip list is inconsistent.');
    }
    return node;
  }

  /// Not part of public API
  void clear() {
    _height = 1;
    for (var i = 0; i < _maxHeight; i++) {
      _head.next[i] = null;
    }
    _height = 1;
    _length = 0;
  }
}

class _Node<K, V> {
  final K? key;

  V? value;

  final List<_Node<K, V>?> next;

  final List<int> width;

  int get level => next.length - 1;

  _Node(this.key, this.value, this.next, this.width);
}

abstract class _Iterator<K, V, E> implements Iterator<E> {
  _Node<K?, V?>? node;

  _Iterator(this.node);

  @override
  bool moveNext() => (node = node?.next[0]) != null;
}

class _KeyIterator<K, V> extends _Iterator<K, V, K> {
  _KeyIterator(_Node<K?, V?> super.node);

  @override
  K get current => node?.key ?? (throw StateError('No current element'));
}

@immutable
class _KeyIterable<K, V> extends IterableBase<K> {
  final _Node<K?, V?> head;

  const _KeyIterable(this.head);

  @override
  Iterator<K> get iterator => _KeyIterator(head);
}

class _ValueIterator<K, V> extends _Iterator<K, V, V> {
  _ValueIterator(_Node<K?, V?> super.node);

  @override
  V get current => node?.value ?? (throw StateError('No current element'));
}

@immutable
class _ValueIterable<K, V> extends IterableBase<V> {
  final _Node<K?, V?> head;

  const _ValueIterable(this.head);

  @override
  Iterator<V> get iterator => _ValueIterator(head);
}
