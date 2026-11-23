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

  final BPlusTree<dynamic, Frame>? _store;
  final PackedLazyBPlusTree<dynamic>? _lazyStore;

  /// Not part of public API
  @visibleForTesting
  final ListQueue<KeyTransaction<E>> transactions = ListQueue();

  var _deletedEntries = 0;
  var _autoIncrement = -1;

  /// Not part of public API
  Keystore(
    this._box,
    this._notifier,
    KeyComparator? keyComparator, {
    bool lazy = false,
  })  : _store = lazy ? null : BPlusTree(keyComparator ?? defaultKeyComparator),
        _lazyStore = lazy
            ? PackedLazyBPlusTree(keyComparator ?? defaultKeyComparator)
            : null;

  /// Not part of public API
  factory Keystore.debug({
    Iterable<Frame> frames = const [],
    BoxBase<E>? box,
    ChangeNotifier? notifier,
    KeyComparator keyComparator = defaultKeyComparator,
    bool lazy = false,
  }) {
    final keystore = Keystore<E>(
      box ?? BoxBaseImpl.nullImpl<E>(),
      notifier ?? ChangeNotifier(),
      keyComparator,
      lazy: lazy,
    );
    for (final frame in frames) {
      keystore.insert(frame, lazy: lazy);
    }
    return keystore;
  }

  /// Not part of public API
  int get deletedEntries => _deletedEntries;

  /// Not part of public API
  int get length {
    if (_store case final store?) {
      return store.length;
    } else if (_lazyStore case final lazyStore?) {
      return lazyStore.length;
    }
    return 0;
  }

  /// Not part of public API
  Iterable<Frame> get frames {
    if (_store case final store?) {
      return store.values;
    } else if (_lazyStore case final lazyStore?) {
      return lazyStore.frames;
    }
    return const Iterable.empty();
  }

  /// Not part of public API
  void resetDeletedEntries() {
    _deletedEntries = 0;
  }

  /// Not part of public API
  void updatePackedOffsets(Iterable<Frame> frames) =>
      _lazyStore?.updateOffsets(frames);

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
    if (_store case final store?) {
      return store.containsKey(key);
    } else if (_lazyStore case final lazyStore?) {
      return lazyStore.containsKey(key);
    }
    return false;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  dynamic keyAt(int index) {
    if (_store case final store?) {
      return store.getKeyAt(index);
    } else if (_lazyStore case final lazyStore?) {
      return lazyStore.getKeyAt(index);
    }
    throw StateError('No backing store.');
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame? get(dynamic key) {
    if (_store case final store?) {
      return store.get(key);
    } else if (_lazyStore case final lazyStore?) {
      return lazyStore.get(key);
    }
    return null;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame? getAt(int index) {
    if (_store case final store?) {
      return store.getAt(index);
    } else if (_lazyStore case final lazyStore?) {
      return lazyStore.getAt(index);
    }
    throw StateError('No backing store.');
  }

  /// Not part of public API
  Iterable<dynamic> getKeys() {
    if (_store case final store?) {
      return store.keys;
    } else if (_lazyStore case final lazyStore?) {
      return lazyStore.keys;
    }
    return const Iterable.empty();
  }

  /// Not part of public API
  Iterable<E> getValues() {
    return frames.map((e) => e.value as E);
  }

  /// Not part of public API
  Iterable<E> getValuesBetween([dynamic startKey, dynamic endKey]) sync* {
    final Iterable<Frame> iterable;
    if (_store case final store?) {
      iterable =
          startKey != null ? store.valuesFromKey(startKey) : store.values;
    } else if (_lazyStore case final lazyStore?) {
      iterable = startKey != null
          ? lazyStore.framesFromKey(startKey)
          : lazyStore.frames;
    } else {
      return;
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

      if (_store case final store?) {
        deletedFrame = store.insert(key, lazy ? frame.toLazy() : frame);
      } else if (_lazyStore case final lazyStore?) {
        deletedFrame = lazyStore.insertLazy(key, frame.offset, frame.length);
      }
    } else {
      if (_store case final store?) {
        deletedFrame = store.delete(frame.key);
      } else if (_lazyStore case final lazyStore?) {
        deletedFrame = lazyStore.deleteLazy(frame.key);
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

      if (_store case final store?) {
        store.insert(key, deletedFrame);
      } else if (_lazyStore case final lazyStore?) {
        lazyStore.insertLazy(key, deletedFrame.offset, deletedFrame.length);
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
        Frame? deletedFrame;
        if (_store case final store?) {
          deletedFrame = store.delete(key);
        } else if (_lazyStore case final lazyStore?) {
          deletedFrame = lazyStore.deleteLazy(key);
        }
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
      final keyList = lazyStore.keys.toList();
      lazyStore.clear();
      for (final key in keyList) {
        _notifier.notify(Frame.deleted(key as Object));
      }
      clearedCount = keyList.length;
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
