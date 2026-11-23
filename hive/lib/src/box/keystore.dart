import 'dart:collection';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/object/hive_object.dart';
import 'package:hive_ce/src/util/b_plus_tree.dart';
import 'package:meta/meta.dart';

import 'package:hive_ce/src/box/box_base_impl.dart';

/// Not part of public API
class KeyTransaction<E> {
  /// The values that have been added
  final List<dynamic> added = [];

  /// The frames that have been deleted
  final Map<dynamic, Frame> deleted = HashMap();

  /// Not part of public API
  @visibleForTesting
  KeyTransaction();
}

/// Not part of public API
class Keystore<E> {
  final BoxBase<E> _box;

  final ChangeNotifier _notifier;

  final KeyComparator _keyComparator;

  BPlusTree<dynamic, Frame>? _store;

  PackedLazyBPlusTree<dynamic>? _lazyStore;

  /// Not part of public API
  @visibleForTesting
  final ListQueue<KeyTransaction<E>> transactions = ListQueue();

  var _deletedEntries = 0;
  var _autoIncrement = -1;

  /// Not part of public API
  Keystore(this._box, this._notifier, KeyComparator? keyComparator)
      : _keyComparator = keyComparator ?? defaultKeyComparator;

  /// Not part of public API
  factory Keystore.debug({
    Iterable<Frame> frames = const [],
    BoxBase<E>? box,
    ChangeNotifier? notifier,
    KeyComparator keyComparator = defaultKeyComparator,
  }) {
    final keystore = Keystore<E>(
      box ?? BoxBaseImpl.nullImpl<E>(),
      notifier ?? ChangeNotifier(),
      keyComparator,
    );
    for (final frame in frames) {
      keystore.insert(frame);
    }
    return keystore;
  }

  BPlusTree<dynamic, Frame> _ensureEagerStore() {
    var store = _store;
    if (store != null) return store;

    store = BPlusTree<dynamic, Frame>(_keyComparator);
    final lazyStore = _lazyStore;
    if (lazyStore != null) {
      for (final frame in lazyStore.frames) {
        store.insert(frame.key, frame);
      }
      _lazyStore = null;
    }
    _store = store;
    return store;
  }

  /// Not part of public API
  int get deletedEntries => _deletedEntries;

  /// Not part of public API
  int get length => _store?.length ?? _lazyStore?.length ?? 0;

  /// Not part of public API
  Iterable<Frame> get frames =>
      _store?.values ?? _lazyStore?.frames ?? const Iterable<Frame>.empty();

  /// Not part of public API
  void resetDeletedEntries() {
    _deletedEntries = 0;
  }

  /// Not part of public API
  void updatePackedOffsets(Iterable<Frame> frames) {
    final lazyStore = _lazyStore;
    if (lazyStore == null) return;
    for (final frame in frames) {
      lazyStore.updateOffsetAndLength(frame.key, frame.offset, frame.length);
    }
  }

  /// Not part of public API
  int autoIncrement() {
    return ++_autoIncrement;
  }

  /// Not part of public API
  void updateAutoIncrement(int key) {
    if (key > _autoIncrement) {
      _autoIncrement = key;
    }
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool containsKey(dynamic key) {
    if (_store case final store?) return store.containsKey(key);
    if (_lazyStore case final lazyStore?) return lazyStore.containsKey(key);
    return false;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  dynamic keyAt(int index) {
    if (_store case final store?) return store.getKeyAt(index);
    if (_lazyStore case final lazyStore?) return lazyStore.getKeyAt(index);
    RangeError.checkValidIndex(index, this, 'index', 0);
    return null;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame? get(dynamic key) {
    return _store?.get(key) ?? _lazyStore?.get(key);
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame? getAt(int index) {
    if (_store case final store?) return store.getAt(index);
    if (_lazyStore case final lazyStore?) return lazyStore.getAt(index);
    RangeError.checkValidIndex(index, this, 'index', 0);
    return null;
  }

  /// Not part of public API
  Iterable<dynamic> getKeys() {
    return _store?.keys ?? _lazyStore?.keys ?? const Iterable<dynamic>.empty();
  }

  /// Not part of public API
  Iterable<E> getValues() {
    return frames.map((e) => e.value as E);
  }

  /// Not part of public API
  Iterable<E> getValuesBetween([dynamic startKey, dynamic endKey]) sync* {
    Iterable<Frame> iterable;
    if (startKey != null) {
      if (_store case final store?) {
        iterable = store.valuesFromKey(startKey);
      } else if (_lazyStore case final lazyStore?) {
        iterable = lazyStore.framesFromKey(startKey);
      } else {
        iterable = const Iterable<Frame>.empty();
      }
    } else {
      iterable = frames;
    }

    for (final frame in iterable) {
      yield frame.value as E;

      if (frame.key == endKey) break;
    }
  }

  /// Not part of public API
  Stream<BoxEvent> watch({dynamic key}) {
    return _notifier.watch(key: key);
  }

  /// Not part of public API
  Frame? insert(Frame frame, {bool notify = true, bool lazy = false}) {
    final value = frame.value;
    Frame? deletedFrame;

    if (!frame.deleted) {
      final key = frame.key;
      if (key is int && key > _autoIncrement) {
        _autoIncrement = key;
      }

      if (value is HiveObjectMixin) {
        value.init(key, _box);
      }

      if (_store == null && (lazy || frame.lazy)) {
        final lazyStore =
            _lazyStore ??= PackedLazyBPlusTree<dynamic>(_keyComparator);
        deletedFrame = lazyStore.insertLazy(key, frame.offset, frame.length);
      } else {
        deletedFrame =
            _ensureEagerStore().insert(key, lazy ? frame.toLazy() : frame);
      }
    } else {
      final key = frame.key;
      if (_store case final store?) {
        deletedFrame = store.delete(key);
      } else if (_lazyStore case final lazyStore?) {
        deletedFrame = lazyStore.deleteLazy(key);
      }
    }

    if (deletedFrame != null) {
      _deletedEntries++;
      if (deletedFrame.value is HiveObjectMixin &&
          !identical(deletedFrame.value, value)) {
        (deletedFrame.value as HiveObjectMixin).dispose();
      }
    }

    if (notify && (!frame.deleted || deletedFrame != null)) {
      _notifier.notify(frame, deletedValue: deletedFrame?.value);
    }

    return deletedFrame;
  }

  /// Not part of public API
  bool beginTransaction(List<Frame> newFrames) {
    final transaction = KeyTransaction<E>();
    for (final frame in newFrames) {
      if (!frame.deleted) {
        transaction.added.add(frame.key);
      }

      final deletedFrame = insert(frame);
      if (deletedFrame != null) {
        transaction.deleted[frame.key] = deletedFrame;
      }
    }

    if (transaction.added.isNotEmpty || transaction.deleted.isNotEmpty) {
      transactions.add(transaction);
      return true;
    } else {
      return false;
    }
  }

  /// Not part of public API
  void commitTransaction() {
    transactions.removeFirst();
  }

  /// Not part of public API
  void cancelTransaction() {
    final canceled = transactions.removeFirst();

    deleted_loop:
    for (final entry in canceled.deleted.entries) {
      final key = entry.key;
      final deletedFrame = entry.value;
      for (final t in transactions) {
        if (t.deleted.containsKey(key)) {
          t.deleted[key] = deletedFrame;
          continue deleted_loop;
        }
        if (t.added.contains(key)) {
          t.deleted[key] = deletedFrame;
          continue deleted_loop;
        }
      }

      if (_store == null && deletedFrame.lazy) {
        (_lazyStore ??= PackedLazyBPlusTree<dynamic>(_keyComparator))
            .insertLazy(key, deletedFrame.offset, deletedFrame.length);
      } else {
        _ensureEagerStore().insert(key, deletedFrame);
      }
      _notifier.notify(deletedFrame);
    }

    added_loop:
    for (final key in canceled.added) {
      final isOverride = canceled.deleted.containsKey(key);
      for (final t in transactions) {
        if (t.deleted.containsKey(key)) {
          if (!isOverride) {
            t.deleted.remove(key);
          }
          continue added_loop;
        }
        if (t.added.contains(key)) {
          continue added_loop;
        }
      }
      if (!isOverride) {
        final deletedFrame = _store?.delete(key) ?? _lazyStore?.deleteLazy(key);
        _notifier.notify(Frame.deleted(key), deletedValue: deletedFrame?.value);
      }
    }
  }

  /// Not part of public API
  int clear() {
    final int clearedCount;
    if (_store case final store?) {
      final frameList = store.values.toList();
      store.clear();

      for (final frame in frameList) {
        if (frame.value is HiveObjectMixin) {
          (frame.value as HiveObjectMixin).dispose();
        }
        _notifier.notify(Frame.deleted(frame.key), deletedValue: frame.value);
      }
      clearedCount = frameList.length;
    } else if (_lazyStore case final lazyStore?) {
      final keys = lazyStore.keys.toList();
      lazyStore.clear();

      for (final key in keys) {
        _notifier.notify(Frame.deleted(key as Object));
      }
      clearedCount = keys.length;
    } else {
      clearedCount = 0;
    }

    _deletedEntries = 0;
    _autoIncrement = -1;
    return clearedCount;
  }

  /// Not part of public API
  Future close() {
    return _notifier.close();
  }
}
