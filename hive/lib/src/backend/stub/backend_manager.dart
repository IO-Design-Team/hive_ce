import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';

/// Not part of public API
class BackendManager implements BackendManagerInterface {
  /// TODO: Document this!
  static BackendManager select([
    HiveStorageBackendPreference? backendPreference,
  ]) =>
      BackendManager();

  @override
  Future<StorageBackend> open(
    String name,
    String? path,
    bool crashRecovery,
    HiveCipher? cipher,
    String? collection,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBox(String name, String? path, String? collection) {
    throw UnimplementedError();
  }

  @override
  Future<bool> boxExists(String name, String? path, String? collection) {
    throw UnimplementedError();
  }
}
