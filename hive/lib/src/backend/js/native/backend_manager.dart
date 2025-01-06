import 'dart:async';
import 'dart:js_interop';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/js/native/storage_backend_js.dart';
import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
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
      debugPrint(
        'Creating objectStore $objectStoreName in database $databaseName...',
      );
      final request = indexedDB!.open(databaseName, db.version + 1);
      request.onupgradeneeded = (IDBVersionChangeEvent e) {
        final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
        if (!db.objectStoreNames.contains(objectStoreName)) {
          db.createObjectStore(objectStoreName);
        }
      }.toJS;
      db = await request.asFuture<IDBDatabase>();
    }

    debugPrint('Got object store $objectStoreName in database $databaseName.');

    return StorageBackendJs(db, cipher, objectStoreName);
  }

  @override
  Future<void> deleteBox(String name, String? path, String? collection) async {
    debugPrint('Delete $name // $collection from disk');

    // compatibility for old store format
    final databaseName = collection ?? name;
    final objectStoreName = collection == null ? 'box' : name;

    // directly deleting the entire DB if a non-collection Box
    if (collection == null) {
      await indexedDB!.deleteDatabase(databaseName).asFuture();
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
        await request.asFuture();
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
