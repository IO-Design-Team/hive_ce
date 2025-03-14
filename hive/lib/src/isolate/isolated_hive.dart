import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';

/// Interface for [IsolatedHive]
abstract class IsolatedHiveInterface implements TypeRegistry {
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
  IsolatedBox<E> box<E>(String name);

  /// Get an object to communicate with the isolated box
  IsolatedLazyBox<E> lazyBox<E>(String name);

  /// Check if a box is open in the isolate
  bool isBoxOpen(String name);

  /// Shutdown the isolate
  Future<void> close();

  /// Delete a box from the disk
  Future<void> deleteBoxFromDisk(String name, {String? path});

  /// Delete all boxes from the disk
  Future<void> deleteFromDisk();

  /// Check if a box exists in the isolate
  Future<bool> boxExists(String name, {String? path});

  /// Reset the adapters in the isolate
  @visibleForTesting
  void resetAdapters();
}
