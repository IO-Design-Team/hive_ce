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

  /// Opens database with timeout and proper event handling.
  /// Returns null if open fails/times out (doesn't throw).
  Future<IDBDatabase?> _tryOpenWithTimeout(
    String databaseName,
    int version,
    void Function(IDBVersionChangeEvent)? onUpgradeNeeded,
    Duration timeout,
  ) async {
    final completer = Completer<IDBDatabase>();

    final request = indexedDB!.open(databaseName, version);

    if (onUpgradeNeeded != null) {
      request.onupgradeneeded = onUpgradeNeeded.toJS;
    }

    request.onsuccess = (Event e) {
      if (!completer.isCompleted) {
        completer.complete(request.result as IDBDatabase);
      }
    }.toJS;

    request.onerror = (Event e) {
      if (!completer.isCompleted) {
        completer.completeError(request.error ?? 'Unknown error');
      }
    }.toJS;

    // Handle blocked state - another connection is preventing upgrade
    request.onblocked = (Event e) {
      debugPrint('IndexedDB open blocked by existing connection');
      if (!completer.isCompleted) {
        completer.completeError('Database open blocked');
      }
    }.toJS;

    try {
      return await completer.future.timeout(timeout);
    } catch (e) {
      debugPrint('Database open failed: $e');
      return null;
    }
  }

  /// Attaches versionchange handler for logging. Does NOT close the connection
  /// immediately - closing during pending async operations crashes Chrome.
  /// The connection will close naturally when the page unloads.
  // ignore: unused_element
  void _attachVersionChangeHandler(IDBDatabase db) {
    db.onversionchange = (Event e) {
      debugPrint('Version change requested - connection will close on page unload');
      // Don't call db.close() here - it crashes Chrome if initialize() is still running
    }.toJS;
  }

  /// Opens IndexedDB with multi-stage recovery for stale connections.
  /// This helps prevent crashes during page reloads in DDC development mode.
  ///
  /// Stage 1: Normal open with short timeout (3 attempts)
  /// Stage 2: Version upgrade to force stale connections to close (3 attempts)
  /// Throws HiveError with clear message if all attempts fail.
  Future<IDBDatabase> _openDatabaseWithRecovery(
    String databaseName,
    int version,
    void Function(IDBVersionChangeEvent)? onUpgradeNeeded,
  ) async {
    // Stage 1: Try normal open with short timeout (3 attempts)
    for (int i = 0; i < 3; i++) {
      debugPrint('Stage 1 attempt ${i + 1}: Normal open of $databaseName');
      final db = await _tryOpenWithTimeout(
        databaseName,
        version,
        onUpgradeNeeded,
        const Duration(seconds: 3),
      );
      if (db != null) {
        return db;
      }
      await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
    }

    // Stage 2: Try version upgrade to force stale connections to close
    debugPrint('Stage 2: Attempting version upgrade to break stale connections');

    // Get current version first (with timeout to avoid hanging)
    int currentVersion = version;
    try {
      final probeDb = await _tryOpenWithTimeout(
        databaseName,
        version,
        null,
        const Duration(seconds: 2),
      );
      if (probeDb != null) {
        currentVersion = probeDb.version;
        probeDb.close();
      }
    } catch (e) {
      debugPrint('Could not probe version: $e');
    }

    // Try opening with incremented version
    for (int i = 0; i < 3; i++) {
      final newVersion = currentVersion + i + 1;
      debugPrint('Stage 2 attempt ${i + 1}: Opening with version $newVersion');
      final db = await _tryOpenWithTimeout(
        databaseName,
        newVersion,
        onUpgradeNeeded,
        const Duration(seconds: 5),
      );
      if (db != null) {
        return db;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // All recovery attempts failed - throw clear error
    throw HiveError(
      'Failed to open IndexedDB "$databaseName" after all recovery attempts. '
      'A stale connection may be blocking access. '
      'Try clearing browser data or restarting the browser.',
    );
  }

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

    IDBDatabase db;

    if (crashRecovery) {
      // Use multi-stage recovery for resilient opening
      db = await _openDatabaseWithRecovery(
        databaseName,
        1,
        (IDBVersionChangeEvent e) {
          final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
          if (!db.objectStoreNames.contains(objectStoreName)) {
            db.createObjectStore(objectStoreName);
          }
        },
      );
    } else {
      // Original behavior without retry
      final request = indexedDB!.open(databaseName, 1);
      request.onupgradeneeded = (IDBVersionChangeEvent e) {
        final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
        if (!db.objectStoreNames.contains(objectStoreName)) {
          db.createObjectStore(objectStoreName);
        }
      }.toJS;
      db = await request.asFuture<IDBDatabase>();
    }

    // in case the objectStore is not contained, re-open the db and
    // update version
    if (!db.objectStoreNames.contains(objectStoreName)) {
      debugPrint(
        'Creating objectStore $objectStoreName in database $databaseName...',
      );

      if (crashRecovery) {
        db = await _openDatabaseWithRecovery(
          databaseName,
          db.version + 1,
          (IDBVersionChangeEvent e) {
            final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
            if (!db.objectStoreNames.contains(objectStoreName)) {
              db.createObjectStore(objectStoreName);
            }
          },
        );
      } else {
        final request = indexedDB!.open(databaseName, db.version + 1);
        request.onupgradeneeded = (IDBVersionChangeEvent e) {
          final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
          if (!db.objectStoreNames.contains(objectStoreName)) {
            db.createObjectStore(objectStoreName);
          }
        }.toJS;
        db = await request.asFuture<IDBDatabase>();
      }
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
