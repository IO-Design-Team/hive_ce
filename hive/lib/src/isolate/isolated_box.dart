import 'package:hive_ce/hive_ce.dart';

/// Isolated version of [BoxBase]
abstract class IsolatedBoxBase<E> {
  /// The name of the box
  String get name;

  /// Whether the box is lazy
  bool get lazy;

  /// Whether the box is open
  bool get isOpen;

  /// The path of the box
  Future<String?> get path;

  /// The keys of the box
  Future<List> get keys;

  /// The length of the box
  Future<int> get length;

  /// Whether the box is empty
  Future<bool> get isEmpty;

  /// Whether the box is not empty
  Future<bool> get isNotEmpty;

  /// The key at the given index
  Future keyAt(int index);

  /// Watch the box for changes filtered by key
  Stream<BoxEvent> watch({dynamic key});

  /// Whether the box contains the given key
  Future<bool> containsKey(dynamic key);

  /// Put a value in the box
  Future<void> put(dynamic key, E value);

  /// Put a value at the given index
  Future<void> putAt(int index, E value);

  /// Put all the given entries in the box
  Future<void> putAll(Map<dynamic, E> entries);

  /// Add a value to the box
  Future<int> add(E value);

  /// Add all the given values to the box
  Future<List<int>> addAll(Iterable<E> values);

  /// Delete a value from the box
  Future<void> delete(dynamic key);

  /// Delete a value at the given index
  Future<void> deleteAt(int index);

  /// Delete all the given values from the box
  Future<void> deleteAll(Iterable keys);

  /// Compact the box
  Future<void> compact();

  /// Clear the box
  Future<int> clear();

  /// Close the box
  Future<void> close();

  /// Delete the box from the disk
  Future<void> deleteFromDisk();

  /// Flush the box
  Future<void> flush();

  /// Get a value from the box
  Future<E?> get(dynamic key, {E? defaultValue});

  /// Get a value from the box and cast the value to [List<T>]
  Future<List<T>?> getList<T>(dynamic key, {List<T>? defaultValue});

  /// Get a value from the box and cast the value to [Set<T>]
  Future<Set<T>?> getSet<T>(dynamic key, {Set<T>? defaultValue});

  /// Get a value from the box and cast the value to [Map<K, V>]
  Future<Map<K, V>?> getMap<K, V>(dynamic key, {Map<K, V>? defaultValue});

  /// Get a value at the given index
  Future<E?> getAt(int index);

  /// Get a value at the given index and cast the value to [List<T>]
  Future<List<T>?> getListAt<T>(int index, {List<T>? defaultValue});

  /// Get a value at the given index and cast the value to [Set<T>]
  Future<Set<T>?> getSetAt<T>(int index, {Set<T>? defaultValue});

  /// Get a value at the given index and cast the value to [Map<K, V>]
  Future<Map<K, V>?> getMapAt<K, V>(int index, {Map<K, V>? defaultValue});
}

/// Isolated version of [Box]
abstract class IsolatedBox<E> extends IsolatedBoxBase<E> {
  /// The values of the box
  Future<Iterable<E>> get values;

  /// The values of the box between the given keys
  Future<Iterable<E>> valuesBetween({dynamic startKey, dynamic endKey});

  /// Convert the box to a map
  Future<Map<dynamic, E>> toMap();
}

/// Isolated version of [LazyBox]
abstract class IsolatedLazyBox<E> extends IsolatedBoxBase<E> {}
