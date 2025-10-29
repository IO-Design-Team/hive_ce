import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/box_base_impl.dart';
import 'package:hive_ce/src/object/hive_object.dart';
import 'package:hive_ce/src/util/type_utils.dart';

/// Not part of public API
class BoxImpl<E> extends BoxBaseImpl<E> implements Box<E> {
  /// Not part of public API
  BoxImpl(
    super.hive,
    super.name,
    super.keyComparator,
    super.compactionStrategy,
    super.backend, {
    super.isolated = false,
  });

  @override
  final lazy = false;

  @override
  Iterable<E> get values {
    checkOpen();

    return keystore.getValues();
  }

  @override
  Iterable<E> valuesBetween({dynamic startKey, dynamic endKey}) {
    checkOpen();

    return keystore.getValuesBetween(startKey, endKey);
  }

  @override
  E? get(dynamic key, {E? defaultValue}) {
    checkOpen();

    final frame = keystore.get(key);
    if (frame != null) {
      return frame.value as E?;
    } else {
      if (defaultValue != null && defaultValue is HiveObjectMixin) {
        defaultValue.init(key, this);
      }
      return defaultValue;
    }
  }

  @override
  List<T>? getList<T>(dynamic key, {List<T>? defaultValue}) =>
      castList(get(key), defaultValue: defaultValue);

  @override
  Set<T>? getSet<T>(dynamic key, {Set<T>? defaultValue}) =>
      castSet(get(key), defaultValue: defaultValue);

  @override
  Map<K, V>? getMap<K, V>(dynamic key, {Map<K, V>? defaultValue}) =>
      castMap(get(key), defaultValue: defaultValue);

  @override
  E? getAt(int index) {
    checkOpen();

    return keystore.getAt(index)?.value as E?;
  }

  @override
  List<T>? getListAt<T>(int index, {List<T>? defaultValue}) =>
      castList(getAt(index), defaultValue: defaultValue);

  @override
  Set<T>? getSetAt<T>(int index, {Set<T>? defaultValue}) =>
      castSet(getAt(index), defaultValue: defaultValue);

  @override
  Map<K, V>? getMapAt<K, V>(int index, {Map<K, V>? defaultValue}) =>
      castMap(getAt(index), defaultValue: defaultValue);

  @override
  Future<void> putAll(Map<dynamic, E> kvPairs) {
    final frames = <Frame>[];
    for (final key in kvPairs.keys) {
      frames.add(Frame(key, kvPairs[key]));
    }

    return _writeFrames(frames);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) {
    final frames = <Frame>[];
    for (final key in keys) {
      if (keystore.containsKey(key)) {
        frames.add(Frame.deleted(key));
      }
    }

    return _writeFrames(frames);
  }

  Future<void> _writeFrames(List<Frame> frames) async {
    checkOpen();

    if (!keystore.beginTransaction(frames)) return;

    try {
      await backend.writeFrames(frames, verbatim: isolated);
      keystore.commitTransaction();
    } catch (e) {
      keystore.cancelTransaction();
      rethrow;
    }

    await performCompactionIfNeeded();
  }

  @override
  Map<dynamic, E> toMap() {
    final map = <dynamic, E>{};
    for (final frame in keystore.frames) {
      map[frame.key] = frame.value as E;
    }
    return map;
  }

  @override
  Future<void> flush() async {
    await backend.flush();
  }
}
