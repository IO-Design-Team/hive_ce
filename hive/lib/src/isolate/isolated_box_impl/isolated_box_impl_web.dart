import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:meta/meta.dart';
import 'package:hive_ce/src/connect/hive_connect_api.dart';
import 'package:hive_ce/src/connect/inspectable_box.dart';

/// Web implementation of [IsolatedBoxBase]
///
/// All operations are delegated to the wrapped [box]
abstract class IsolatedBoxBaseImpl<E>
    implements IsolatedBoxBase<E>, InspectableBox {
  BoxBase<E> get _box;

  @override
  String get name => _box.name;

  @override
  bool get lazy => _box.lazy;

  @override
  bool get isOpen => _box.isOpen;

  @override
  Future<String?> get path async => _box.path;

  @override
  Future<List> get keys async => _box.keys.toList();

  @override
  Future<int> get length async => _box.length;

  @override
  Future<bool> get isEmpty async => _box.isEmpty;

  @override
  Future<bool> get isNotEmpty async => _box.isNotEmpty;

  @override
  Future keyAt(int index) async => _box.keyAt(index);

  @override
  Stream<BoxEvent> watch({dynamic key}) => _box.watch(key: key);

  @override
  Future<bool> containsKey(dynamic key) async => _box.containsKey(key);

  @override
  Future<void> put(dynamic key, E value) => _box.put(key, value);

  @override
  Future<void> putAt(int index, E value) => _box.putAt(index, value);

  @override
  Future<void> putAll(Map<dynamic, E> entries) => _box.putAll(entries);

  @override
  Future<int> add(E value) => _box.add(value);

  @override
  Future<List<int>> addAll(Iterable<E> values) async {
    final keys = await _box.addAll(values);
    return keys.toList();
  }

  @override
  Future<void> delete(dynamic key) => _box.delete(key);

  @override
  Future<void> deleteAt(int index) => _box.deleteAt(index);

  @override
  Future<void> deleteAll(Iterable keys) => _box.deleteAll(keys);

  @override
  Future<void> compact() => _box.compact();

  @override
  Future<int> clear() => _box.clear();

  @override
  Future<void> close() => _box.close();

  @override
  Future<void> deleteFromDisk() => _box.deleteFromDisk();

  @override
  Future<void> flush() => _box.flush();

  @override
  Future<E?> get(dynamic key, {E? defaultValue}) async {
    if (lazy) {
      return (_box as LazyBox<E>).get(key, defaultValue: defaultValue);
    } else {
      return (_box as Box<E>).get(key, defaultValue: defaultValue);
    }
  }

  @override
  Future<E?> getAt(int index) async {
    if (lazy) {
      return (_box as LazyBox<E>).getAt(index);
    } else {
      return (_box as Box<E>).getAt(index);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is IsolatedBoxBaseImpl && other._box == _box;
  }

  @override
  int get hashCode => _box.hashCode;

  @override
  TypeRegistry get typeRegistry => (_box as InspectableBox).typeRegistry;

  @override
  Future<Iterable<InspectorFrame>> getFrames() =>
      (_box as InspectableBox).getFrames();
}

/// Isolated implementation of [Box]
@immutable
class IsolatedBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedBox<E> {
  @override
  final Box<E> _box;

  /// Constructor
  IsolatedBoxImpl(this._box);

  @override
  Future<Iterable<E>> get values async => _box.values;

  @override
  Future<Iterable<E>> valuesBetween({dynamic startKey, dynamic endKey}) async =>
      _box.valuesBetween(startKey: startKey, endKey: endKey);

  @override
  Future<Map<dynamic, E>> toMap() async => _box.toMap();
}

/// Isolated implementation of [LazyBoxBase]
@immutable
class IsolatedLazyBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedLazyBox<E> {
  @override
  final LazyBox<E> _box;

  /// Constructor
  IsolatedLazyBoxImpl(this._box);
}
