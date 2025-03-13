import 'dart:async';

import 'package:hive_ce/hive.dart';

/// Web implementation of [IsolatedBoxBase]
///
/// All operations are delegated to the wrapped [box]
abstract class IsolatedBoxBaseImpl<E> implements IsolatedBoxBase<E> {
  BoxBase<E> get _box;

  @override
  String get name => _box.name;

  @override
  bool get lazy => _box.lazy;

  @override
  Future<bool> get isOpen async => _box.isOpen;

  @override
  Future<String?> get path async => _box.path;

  @override
  Future<Iterable> get keys async => _box.keys;

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
  Future<Iterable<int>> addAll(Iterable<E> values) => _box.addAll(values);

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
    final box = _box;
    if (box is Box<E>) {
      return box.get(key, defaultValue: defaultValue);
    } else if (box is LazyBox<E>) {
      return box.get(key, defaultValue: defaultValue);
    } else {
      throw UnimplementedError();
    }
  }

  @override
  Future<E?> getAt(int index) async {
    final box = _box;
    if (box is Box<E>) {
      return box.getAt(index);
    } else if (box is LazyBox<E>) {
      return box.getAt(index);
    } else {
      throw UnimplementedError();
    }
  }
}

/// Isolated implementation of [Box]
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
class IsolatedLazyBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedLazyBox<E> {
  @override
  final LazyBox<E> _box;

  /// Constructor
  IsolatedLazyBoxImpl(this._box);
}
