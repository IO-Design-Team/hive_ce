import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';

import 'package:hive_ce/src/backend/js/native/backend_manager.dart' as native;

/// Opens IndexedDB databases
abstract class BackendManager {
  BackendManager._();

  // dummy implementation as the WebWorker branch is not stable yet
  /// TODO: Document this!
  static BackendManagerInterface select([
    HiveStorageBackendPreference? backendPreference,
  ]) {
    switch (backendPreference) {
      default:
        return native.BackendManager();
    }
  }
}
