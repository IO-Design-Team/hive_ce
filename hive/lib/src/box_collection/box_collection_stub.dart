import 'dart:async';
import 'package:hive_ce/hive.dart';

/// TODO: Document this!
abstract class BoxCollection {
  /// TODO: Document this!
  String get name;

  /// TODO: Document this!
  Set<String> get boxNames;

  /// TODO: Document this!
  static Future<BoxCollection> open(
    String name,
    Set<String> boxNames, {
    String? path,
    HiveCipher? key,
  }) {
    throw UnimplementedError();
  }

  /// TODO: Document this!
  Future<CollectionBox<V>> openBox<V>(
    String name, {
    bool preload = false,
    CollectionBox<V> Function(String, BoxCollection)? boxCreator,
  });

  /// TODO: Document this!
  Future<void> transaction(
    Future<void> Function() action, {
    List<String>? boxNames,
    bool readOnly = false,
  });

  /// TODO: Document this!
  void close();

  /// TODO: Document this!
  Future<void> deleteFromDisk();
}

/// represents a [Box] being part of a [BoxCollection]
abstract class CollectionBox<V> {
  /// TODO: Document this!
  String get name;

  /// TODO: Document this!
  BoxCollection get boxCollection;

  /// From json
  V Function(Map<String, dynamic>)? get fromJson;

  /// TODO: Document this!
  Future<List<String>> getAllKeys();

  /// TODO: Document this!
  Future<Map<String, V>> getAllValues();

  /// TODO: Document this!
  Future<V?> get(String key);

  /// TODO: Document this!
  Future<List<V?>> getAll(
    List<String> keys,
  );

  /// TODO: Document this!
  Future<void> put(String key, V val, [Object? transaction]);

  /// TODO: Document this!
  Future<void> delete(String key);

  /// TODO: Document this!
  Future<void> deleteAll(List<String> keys);

  /// TODO: Document this!
  Future<void> clear();

  /// TODO: Document this!
  Future<void> flush();
}
