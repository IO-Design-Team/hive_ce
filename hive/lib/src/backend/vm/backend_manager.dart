import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/backend/vm/storage_backend_vm.dart';
import 'package:hive_ce/src/util/obfuscation_utils.dart';
import 'package:meta/meta.dart';

/// Not part of public API
class BackendManager implements BackendManagerInterface {
  final _delimiter = Platform.isWindows ? '\\' : '/';

  /// Creates and configures a [BackendManager] instance.
  ///
  /// [backendPreference] specifies the preferred storage backend (currently unused).
  /// [obfuscateBoxNames] enables obfuscation of box names and file extensions on disk.
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

    final (file, lockFile) =
        await findHiveFileAndCleanUp(name, path, obfuscateBoxNames);

    final backend = StorageBackendVm(file, lockFile, crashRecovery, cipher);
    await backend.open();
    return backend;
  }

  Future<void> _migrateFileIfNeeded(File oldFile, File newFile) async {
    final results = await Future.wait([
      oldFile.exists(),
      newFile.exists(),
    ]);
    if (results[0]) {
      if (results[1]) {
        await oldFile.delete();
      } else {
        await oldFile.rename(newFile.path);
      }
    }
  }

  /// Not part of public API
  @visibleForTesting
  Future<(File, File)> findHiveFileAndCleanUp(
    String name,
    String path,
    bool obfuscateBoxNames,
  ) async {
    var hiveFile = File('$path$_delimiter$name.hive');
    var compactedFile = File('$path$_delimiter$name.hivec');
    var lockFile = File('$path$_delimiter$name.lock');

    if (obfuscateBoxNames) {
      await Future.wait([
        _migrateFileIfNeeded(hiveFile, hiveFile.obfuscate(obfuscateBoxNames)),
        _migrateFileIfNeeded(
          compactedFile,
          compactedFile.obfuscate(obfuscateBoxNames),
        ),
        _migrateFileIfNeeded(
          lockFile,
          lockFile.obfuscate(obfuscateBoxNames),
        ),
      ]);

      hiveFile = hiveFile.obfuscate(obfuscateBoxNames);
      compactedFile = compactedFile.obfuscate(obfuscateBoxNames);
      lockFile = lockFile.obfuscate(obfuscateBoxNames);
    }

    final fileChecks = await Future.wait([
      hiveFile.exists(),
      compactedFile.exists(),
    ]);

    final hiveExists = fileChecks[0];
    final compactedExists = fileChecks[1];

    if (hiveExists) {
      if (compactedExists) {
        await compactedFile.delete();
      }
      return (hiveFile, lockFile);
    } else if (compactedExists) {
      return (await compactedFile.rename(hiveFile.path), lockFile);
    } else {
      await hiveFile.create();
      return (hiveFile, lockFile);
    }
  }

  @override
  Future<void> deleteBox(
    String name,
    String? path,
    String? collection,
  ) async {
    ArgumentError.checkNotNull(path, 'path');

    if (path!.endsWith(_delimiter)) path = path.substring(0, path.length - 1);

    if (collection != null) {
      path = path + collection;
    }

    await Future.wait(
      [
        File('$path$_delimiter$name.hive'),
        File('$path$_delimiter$name.hivec'),
        File('$path$_delimiter$name.lock'),
        File('$path$_delimiter$name.hive').obfuscate(true),
        File('$path$_delimiter$name.hivec').obfuscate(true),
        File('$path$_delimiter$name.lock').obfuscate(true),
      ].map(_deleteFileIfExists),
    );
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

    return await Future.wait(
      [
        File('$path$_delimiter$name.hive'),
        File('$path$_delimiter$name.hivec'),
        File('$path$_delimiter$name.lock'),
      ].map(
        (file) async =>
            await file.exists() ||
            obfuscateBoxNames &&
                await file.obfuscate(obfuscateBoxNames).exists(),
      ),
    ).then((exists) => exists.any((exists) => exists));
  }
}
