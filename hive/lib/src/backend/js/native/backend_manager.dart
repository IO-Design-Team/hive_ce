import 'dart:async';
import 'dart:js_interop';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/backend/js/native/storage_backend_js.dart';
import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/util/logger.dart';
import 'package:web/web.dart';

/// Opens IndexedDB databases
class BackendManager implements BackendManagerInterface {
  /// TODO: Document this!
  IDBFactory? get indexedDB => window.self.indexedDB;

  @override
  Future<StorageBackend> open(
    String name,
    String? path,
    bool crashRecovery,
    HiveCipher? cipher,
    int? keyCrc,
    String? collection,
  ) async {
    // compatibility for old store format
    final databaseName = collection ?? name;
    final objectStoreName = collection == null ? 'box' : name;

    final request = indexedDB!.open(databaseName, 1);
    request.onupgradeneeded = (IDBVersionChangeEvent e) {
      final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
      if (!db.objectStoreNames.contains(objectStoreName)) {
        db.createObjectStore(objectStoreName);
      }
    }.toJS;
    var db = await request.asFuture<IDBDatabase>();

    // in case the objectStore is not contained, re-open the db and
    // update version
    if (!db.objectStoreNames.contains(objectStoreName)) {
      Logger.i(
        'Creating objectStore $objectStoreName in database $databaseName...',
      );
      // Close the existing connection before requesting a version upgrade.
      // IndexedDB blocks upgrades until all existing connections are
      // closed; without this the second open() would hang forever.
      db.close();
      await Future.delayed(const Duration(milliseconds: 50));
      final request = indexedDB!.open(databaseName, db.version + 1);
      request.onupgradeneeded = (IDBVersionChangeEvent e) {
        final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
        if (!db.objectStoreNames.contains(objectStoreName)) {
          db.createObjectStore(objectStoreName);
        }
      }.toJS;
      db = await request.asFuture<IDBDatabase>();
    }

    Logger.i('Got object store $objectStoreName in database $databaseName.');

    return StorageBackendJs(db, cipher, objectStoreName);
  }

  @override
  Future<void> deleteBox(String name, String? path, String? collection) async {
    Logger.d('Delete $name // $collection from disk');

    // compatibility for old store format
    final databaseName = collection ?? name;
    final objectStoreName = collection == null ? 'box' : name;

    // directly deleting the entire DB if a non-collection Box
    if (collection == null) {
      await indexedDB!.deleteDatabase(databaseName).asFuture();
      // Firefox (and some privacy modes) need a beat before the database
      // is truly released. Without this delay the next open() can hang.
      await Future.delayed(const Duration(milliseconds: 100));
    } else {
      final request = indexedDB!.open(databaseName, 1);
      request.onupgradeneeded = (IDBVersionChangeEvent e) {
        final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
        if (db.objectStoreNames.contains(objectStoreName)) {
          db.deleteObjectStore(objectStoreName);
        }
      }.toJS;
      final db = await request.asFuture<IDBDatabase>();
      if (db.objectStoreNames.length == 0) {
        db.close();
        await Future.delayed(const Duration(milliseconds: 50));
        await indexedDB!.deleteDatabase(databaseName).asFuture();
      }
    }
  }

  @override
  Future<bool> boxExists(String name, String? path, String? collection) async {
    // compatibility for old store format
    final databaseName = collection ?? name;
    final objectStoreName = collection == null ? 'box' : name;
    // https://stackoverflow.com/a/17473952
    try {
      var exists = true;
      if (collection == null) {
        final request = indexedDB!.open(databaseName, 1);
        request.onupgradeneeded = (IDBVersionChangeEvent e) {
          (e.target as IDBOpenDBRequest).transaction!.abort();
          exists = false;
        }.toJS;
        try {
          final db = await request.asFuture<IDBDatabase>();
          // open() succeeded without upgrade. Verify it has the object store;
          // otherwise this is a ghost database left by a previous aborted
          // existence check and must be cleaned up.
          if (!db.objectStoreNames.contains(objectStoreName)) {
            db.close();
            await Future.delayed(const Duration(milliseconds: 50));
            await indexedDB!.deleteDatabase(databaseName).asFuture();
            exists = false;
          }
        } catch (_) {
          exists = false;
        }
      } else {
        final request = indexedDB!.open(collection, 1);
        request.onupgradeneeded = (IDBVersionChangeEvent e) {
          final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
          exists = db.objectStoreNames.contains(objectStoreName);
        }.toJS;
        final db = await request.asFuture<IDBDatabase>();
        exists = db.objectStoreNames.contains(objectStoreName);
      }
      return exists;
    } catch (error) {
      return false;
    }
  }
}
