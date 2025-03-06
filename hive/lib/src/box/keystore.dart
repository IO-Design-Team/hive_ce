import 'dart:collection';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/object/hive_object.dart';
import 'package:hive_ce/src/util/indexable_skip_list.dart';
import 'package:meta/meta.dart';

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
  final String _boxName;

  final ChangeNotifier _notifier;

  final IndexableSkipList<dynamic, Frame> _store;

  /// Not part of public API
  @visibleForTesting
  final ListQueue<KeyTransaction<E>> transactions = ListQueue();

  var _deletedEntries = 0;
  var _autoIncrement = -1;

  /// Not part of public API
  Keystore(this._boxName, this._notifier, KeyComparator? keyComparator)
      : _store = IndexableSkipList(keyComparator ?? defaultKeyComparator);

  /// Not part of public API
  factory Keystore.debug({
    Iterable<Frame> frames = const [],
    String? boxName,
    ChangeNotifier? notifier,
    KeyComparator keyComparator = defaultKeyComparator,
  }) {
    final keystore = Keystore<E>(
      boxName ?? '',
      notifier ?? ChangeNotifier(),
      keyComparator,
    );
    for (final frame in frames) {
      keystore.insert(frame);
    }
    return keystore;
  }

  /// Not part of public API
  int get deletedEntries => _deletedEntries;

  /// Not part of public API
  int get length => _store.length;

  /// Not part of public API
  Iterable<Frame> get frames => _store.values;

  /// Not part of public API
  void resetDeletedEntries() {
    _deletedEntries = 0;
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
    return _store.get(key) != null;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  dynamic keyAt(int index) {
    return _store.getKeyAt(index);
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame? get(dynamic key) {
    return _store.get(key);
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Frame? getAt(int index) {
    return _store.getAt(index);
  }

  /// Not part of public API
  Iterable<dynamic> getKeys() {
    return _store.keys;
  }

  /// Not part of public API
  Iterable<E> getValues() {
    return _store.values.map((e) => e.value as E);
  }

  /// Not part of public API
  Iterable<E> getValuesBetween([dynamic startKey, dynamic endKey]) sync* {
    Iterable<Frame> iterable;
    if (startKey != null) {
      iterable = _store.valuesFromKey(startKey);
    } else {
      iterable = _store.values;
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
        value.init(key, _boxName);
      }

      deletedFrame = _store.insert(key, lazy ? frame.toLazy() : frame);
    } else {
      deletedFrame = _store.delete(frame.key);
    }

    if (deletedFrame != null) {
      _deletedEntries++;
      if (deletedFrame.value is HiveObjectMixin &&
          !identical(deletedFrame.value, value)) {
        (deletedFrame.value as HiveObjectMixin).dispose();
      }
    }

    if (notify && (!frame.deleted || deletedFrame != null)) {
      _notifier.notify(frame);
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
    for (final key in canceled.deleted.keys) {
      final deletedFrame = canceled.deleted[key];
      for (final t in transactions) {
        if (t.deleted.containsKey(key)) {
          t.deleted[key] = deletedFrame!;
          continue deleted_loop;
        }
        if (t.added.contains(key)) {
          t.deleted[key] = deletedFrame!;
          continue deleted_loop;
        }
      }

      _store.insert(key, deletedFrame);
      _notifier.notify(deletedFrame!);
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
        _store.delete(key);
        _notifier.notify(Frame.deleted(key));
      }
    }
  }

  /// Not part of public API
  int clear() {
    final frameList = frames.toList();

    _store.clear();

    for (final frame in frameList) {
      if (frame.value is HiveObjectMixin) {
        (frame.value as HiveObjectMixin).dispose();
      }
      _notifier.notify(Frame.deleted(frame.key));
    }

    _deletedEntries = 0;
    _autoIncrement = -1;
    return frameList.length;
  }

  /// Not part of public API
  Future close() {
    return _notifier.close();
  }
}
