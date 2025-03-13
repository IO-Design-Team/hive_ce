import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

/// Web implementation of [IsolatedHiveInterface]
///
/// Just a wrapper for normal [Hive] operations
class IsolatedHiveImpl implements IsolatedHiveInterface {
  /// Initialize the isolated Hive instance
  ///
  /// If accessing Hive in multiple isolates, an [isolateNameSever] MUST be
  /// passed to avoid box corruption
  @override
  Future<void> init(
    String? path, {
    IsolateNameServer? isolateNameServer,
  }) async =>
      Hive.init(path);

  /// Open a box in the isolate
  @override
  Future<IsolatedBox<E>> openBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    Uint8List? bytes,
    String? collection,
  }) =>
      throw UnimplementedError();

  /// Open a lazy box in the isolate
  Future<IsolatedLazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) =>
      throw UnimplementedError();

  /// Get an object to communicate with the isolated box
  @override
  Future<IsolatedBox<E>> box<E>(String name) => throw UnimplementedError();

  /// Get an object to communicate with the isolated box
  @override
  Future<IsolatedLazyBox<E>> lazyBox<E>(String name) =>
      throw UnimplementedError();

  /// Check if a box is open in the isolate
  @override
  Future<bool> isBoxOpen(String name) async => Hive.isBoxOpen(name);

  /// Shutdown the isolate
  @override
  Future<void> close() => Hive.close();

  /// Delete a box from the disk
  @override
  Future<void> deleteBoxFromDisk(String name, {String? path}) =>
      Hive.deleteBoxFromDisk(name, path: path);

  /// Delete all boxes from the disk
  @override
  Future<void> deleteFromDisk() => Hive.deleteFromDisk();

  /// Check if a box exists in the isolate
  @override
  Future<bool> boxExists(String name, {String? path}) =>
      Hive.boxExists(name, path: path);

  /// Register an adapter in the isolate
  ///
  /// WARNING: Validation checks are not as strong as with [Hive]
  @override
  Future<void> registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) async =>
      Hive.registerAdapter(adapter, internal: internal, override: override);

  /// Check if an adapter is registered in the isolate
  @override
  Future<bool> isAdapterRegistered(int typeId) async =>
      Hive.isAdapterRegistered(typeId);

  /// Reset the adapters in the isolate
  @override
  Future<void> resetAdapters() async {
    // This is an override
    // ignore: invalid_use_of_visible_for_testing_member
    Hive.resetAdapters();
  }

  /// Ignore a type id in the isolate
  @override
  Future<void> ignoreTypeId<T>(int typeId) async =>
      Hive.ignoreTypeId<T>(typeId);
}
