import 'package:hive_ce/src/box/box_base.dart';

/// [LazyBox]es don't keep the values in memory like normal boxes. Each time a
/// value is read, it is loaded from the backend.
abstract class LazyBox<E> extends BoxBase<E> {
  /// Returns the value associated with the given [key]. If the key does not
  /// exist, `null` is returned.
  ///
  /// If [defaultValue] is specified, it is returned in case the key does not
  /// exist.
  Future<E?> get(dynamic key, {E? defaultValue});

  /// Read the given [key] and cast the value to [List<T>]
  Future<List<T>?> getList<T>(dynamic key, {List<T>? defaultValue});

  /// Read the given [key] and cast the value to [Set<T>]
  Future<Set<T>?> getSet<T>(dynamic key, {Set<T>? defaultValue});

  /// Read the given [key] and cast the value to [Map<K, V>]
  Future<Map<K, V>?> getMap<K, V>(dynamic key, {Map<K, V>? defaultValue});

  /// Returns the value associated with the n-th key.
  Future<E?> getAt(int index);

  /// Read the value at the given [index] and cast the value to [List<T>]
  Future<List<T>?> getListAt<T>(int index, {List<T>? defaultValue});

  /// Read the value at the given [index] and cast the value to [Set<T>]
  Future<Set<T>?> getSetAt<T>(int index, {Set<T>? defaultValue});

  /// Read the value at the given [index] and cast the value to [Map<K, V>]
  Future<Map<K, V>?> getMapAt<K, V>(int index, {Map<K, V>? defaultValue});
}
