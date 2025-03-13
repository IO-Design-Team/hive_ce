import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

/// Interface for [IsolatedHive]
abstract class IsolatedHiveInterface {
  /// Initialize the isolated Hive instance
  ///
  /// If accessing Hive in multiple isolates, an [isolateNameSever] MUST be
  /// passed to avoid box corruption
  Future<void> init(
    String? path, {
    IsolateNameServer? isolateNameServer,
  });

  /// Open a box in the isolate
  Future<IsolatedBox<E>> openBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    Uint8List? bytes,
    String? collection,
  });

  /// Open a lazy box in the isolate
  Future<IsolatedLazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
  });

  /// Get an object to communicate with the isolated box
  Future<IsolatedBox<E>> box<E>(String name);

  /// Get an object to communicate with the isolated box
  Future<IsolatedLazyBox<E>> lazyBox<E>(String name);

  /// Check if a box is open in the isolate
  Future<bool> isBoxOpen(String name);

  /// Shutdown the isolate
  Future<void> close();

  /// Delete a box from the disk
  Future<void> deleteBoxFromDisk(String name, {String? path});

  /// Delete all boxes from the disk
  Future<void> deleteFromDisk();

  /// Check if a box exists in the isolate
  Future<bool> boxExists(String name, {String? path});

  /// Register an adapter in the isolate
  ///
  /// WARNING: Validation checks are not as strong as with [Hive]
  Future<void> registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  });

  /// Check if an adapter is registered in the isolate
  Future<bool> isAdapterRegistered(int typeId);

  /// Reset the adapters in the isolate
  Future<void> resetAdapters();

  /// Ignore a type id in the isolate
  Future<void> ignoreTypeId<T>(int typeId);
}
