import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/backend/vm/storage_backend_vm.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:hive_ce/src/util/obfuscation_utils.dart';
import 'package:meta/meta.dart';

/// Not part of public API
class BackendManager implements BackendManagerInterface {
  final _delimiter = Platform.isWindows ? '\\' : '/';
  var _obfuscateBoxNames = false;

  // File extensions for Hive box files
  static const _hiveExtension = '.hive';
  static const _compactedExtension = '.hivec';
  static const _lockExtension = '.lock';

  /// Creates and configures a [BackendManager] instance.
  ///
  /// [backendPreference] specifies the preferred storage backend (currently unused).
  /// [obfuscateBoxNames] enables obfuscation of box names and file extensions on disk.
  static BackendManager select([
    HiveStorageBackendPreference? backendPreference,
    bool obfuscateBoxNames = false,
  ]) {
    final manager = BackendManager();
    manager._obfuscateBoxNames = obfuscateBoxNames;
    return manager;
  }

  @override
  Future<StorageBackend> open(
    String name,
    String? path,
    bool crashRecovery,
    HiveCipher? cipher,
    String? collection,
    bool obfuscateBoxNames,
  ) async {
    if (path == null) {
      throw HiveError('You need to initialize Hive or '
          'provide a path to store the box.');
    }

    if (path.endsWith(_delimiter)) path = path.substring(0, path.length - 1);

    if (collection != null) {
      path = path + collection;
    }

    final dir = Directory(path);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = await findHiveFileAndCleanUp(name, path);
    final lockFileName = _getFileName(name, _lockExtension);
    final lockFile = File('$path$_delimiter$lockFileName');

    final backend = StorageBackendVm(file, lockFile, crashRecovery, cipher);
    await backend.open();
    return backend;
  }

  /// Returns the filename for a box with the given extension.
  ///
  /// If obfuscation is enabled, the entire name (including extension) is hashed.
  /// Otherwise, returns the standard format: `{name}{extension}`.
  String _getFileName(String boxName, String extension) {
    if (_obfuscateBoxNames) {
      return obfuscateBoxName('$boxName$extension');
    }
    return '$boxName$extension';
  }

  /// Not part of public API
  @visibleForTesting
  Future<File> findHiveFileAndCleanUp(
    String name,
    String path,
  ) async {
    final hiveFileName = _getFileName(name, _hiveExtension);
    final compactedFileName = _getFileName(name, _compactedExtension);

    final hiveFile = File('$path$_delimiter$hiveFileName');
    final compactedFile = File('$path$_delimiter$compactedFileName');

    if (await hiveFile.exists()) {
      if (await compactedFile.exists()) {
        await compactedFile.delete();
      }
      return hiveFile;
    } else if (await compactedFile.exists()) {
      debugPrint('Restoring compacted file.');
      return await compactedFile.rename(hiveFile.path);
    } else {
      await hiveFile.create();
      return hiveFile;
    }
  }

  @override
  Future<void> deleteBox(
    String name,
    String? path,
    String? collection,
    bool obfuscateBoxNames,
  ) async {
    ArgumentError.checkNotNull(path, 'path');

    if (path!.endsWith(_delimiter)) path = path.substring(0, path.length - 1);

    if (collection != null) {
      path = path + collection;
    }

    final hiveFileName = _getFileName(name, _hiveExtension);
    final compactedFileName = _getFileName(name, _compactedExtension);
    final lockFileName = _getFileName(name, _lockExtension);

    await _deleteFileIfExists(File('$path$_delimiter$hiveFileName'));
    await _deleteFileIfExists(File('$path$_delimiter$compactedFileName'));
    await _deleteFileIfExists(File('$path$_delimiter$lockFileName'));
  }

  Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> boxExists(
    String name,
    String? path,
    String? collection,
    bool obfuscateBoxNames,
  ) async {
    ArgumentError.checkNotNull(path, 'path');

    if (path!.endsWith(_delimiter)) path = path.substring(0, path.length - 1);

    if (collection != null) {
      path = path + collection;
    }

    final hiveFileName = _getFileName(name, _hiveExtension);
    final compactedFileName = _getFileName(name, _compactedExtension);
    final lockFileName = _getFileName(name, _lockExtension);

    return await File('$path$_delimiter$hiveFileName').exists() ||
        await File('$path$_delimiter$compactedFileName').exists() ||
        await File('$path$_delimiter$lockFileName').exists();
  }
}
