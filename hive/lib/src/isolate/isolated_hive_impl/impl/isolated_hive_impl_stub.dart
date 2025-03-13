import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

/// Stub implementation of [IsolatedHiveInterface]
class IsolatedHiveImpl implements IsolatedHiveInterface {
  @override
  Future<IsolatedBox<E>> box<E>(String name) {
    throw UnimplementedError();
  }

  @override
  Future<bool> boxExists(String name, {String? path}) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBoxFromDisk(String name, {String? path}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFromDisk() {
    throw UnimplementedError();
  }

  @override
  Future<void> ignoreTypeId<T>(int typeId) {
    throw UnimplementedError();
  }

  @override
  Future<void> init(String? path, {IsolateNameServer? isolateNameServer}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> isAdapterRegistered(int typeId) {
    throw UnimplementedError();
  }

  @override
  Future<bool> isBoxOpen(String name) {
    throw UnimplementedError();
  }

  @override
  Future<IsolatedLazyBox<E>> lazyBox<E>(String name) {
    throw UnimplementedError();
  }

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<IsolatedLazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> resetAdapters() {
    throw UnimplementedError();
  }
}
