import 'dart:async';
import 'dart:js_interop';
import 'package:hive/hive.dart';
import 'package:hive/src/backend/js/native/storage_backend_js.dart';
import 'package:hive/src/backend/storage_backend.dart';
import 'package:web/web.dart';

/// Opens IndexedDB databases
class BackendManager implements BackendManagerInterface {
  IDBFactory? get indexedDB => window.self.indexedDB;

  @override
  Future<StorageBackend> open(String name, String? path, bool crashRecovery,
      HiveCipher? cipher, String? collection) async {
    // compatibility for old store format
    final databaseName = collection ?? name;
    final objectStoreName = collection == null ? 'box' : name;

    var db = await openDatabase(
      databaseName,
      onUpgradeNeeded: (e) {
        var db = e.target.result as IDBDatabase;
        if (!db.objectStoreNames.contains(objectStoreName)) {
          db.createObjectStore(objectStoreName);
        }
      },
    );

    // in case the objectStore is not contained, re-open the db and
    // update version
    if (!db.objectStoreNames.contains(objectStoreName)) {
      print(
          'Creating objectStore $objectStoreName in database $databaseName...');
      db = await openDatabase(
        databaseName,
        version: db.version + 1,
        onUpgradeNeeded: (e) {
          var db = e.target.result as IDBDatabase;
          if (!db.objectStoreNames.contains(objectStoreName)) {
            db.createObjectStore(objectStoreName);
          }
        },
      );
    }

    print('Got object store $objectStoreName in database $databaseName.');

    return StorageBackendJs(db, cipher, objectStoreName);
  }

  @override
  Future<void> deleteBox(String name, String? path, String? collection) async {
    print('Delete $name // $collection from disk');

    // compatibility for old store format
    final databaseName = collection ?? name;
    final objectStoreName = collection == null ? 'box' : name;

    // directly deleting the entire DB if a non-collection Box
    if (collection == null) {
      await deleteDatabase(databaseName);
    } else {
      final db = await openDatabase(databaseName, onUpgradeNeeded: (e) {
        var db = e.target.result as IDBDatabase;
        if (db.objectStoreNames.contains(objectStoreName)) {
          db.deleteObjectStore(objectStoreName);
        }
      });
      if (db.objectStoreNames.length == 0) {
        await deleteDatabase(databaseName);
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
      var _exists = true;
      if (collection == null) {
        await openDatabase(databaseName, onUpgradeNeeded: (e) {
          e.target.transaction!.abort();
          _exists = false;
        });
      } else {
        final db = await openDatabase(collection, onUpgradeNeeded: (e) {
          var db = e.target.result as IDBDatabase;
          _exists = db.objectStoreNames.contains(objectStoreName);
        });
        _exists = db.objectStoreNames.contains(objectStoreName);
      }
      return _exists;
    } catch (error) {
      return false;
    }
  }

  Future<IDBDatabase> openDatabase(
    String name, {
    int version = 1,
    void Function(dynamic event)? onUpgradeNeeded,
  }) async {
    final request = indexedDB!.open(name, version);
    request.onupgradeneeded = onUpgradeNeeded?.toJS;

    final completer = Completer<IDBDatabase>();
    request.onsuccess = (e) {
      completer.complete(e.target.result as IDBDatabase);
    }.toJS;
    return completer.future;
  }

  Future<void> deleteDatabase(String name) async {
    final request = indexedDB!.deleteDatabase(name);
    final completer = Completer();
    request.onsuccess = (e) {
      completer.complete();
    }.toJS;
    request.onerror = completer.completeError.toJS;
    return completer.future;
  }
}
