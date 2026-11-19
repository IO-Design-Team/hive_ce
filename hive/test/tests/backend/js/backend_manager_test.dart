@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:hive_ce/src/backend/js/backend_manager.dart';
import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

Future<IDBDatabase> _openDb() {
  final request = window.self.indexedDB.open('testBox', 1);
  request.onupgradeneeded = (IDBVersionChangeEvent e) {
    final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
    if (!db.objectStoreNames.contains('box')) {
      db.createObjectStore('box');
    }
  }.toJS;
  return request.asFuture<IDBDatabase>();
}

Future<void> _createDb(String name, {String? storeName}) async {
  final request = window.self.indexedDB.open(name, 1);
  if (storeName != null) {
    request.onupgradeneeded = (IDBVersionChangeEvent e) {
      final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
      db.createObjectStore(storeName);
    }.toJS;
  }
  final db = await request.asFuture<IDBDatabase>();
  db.close();
}

Future<void> _addObjectStore(String dbName, String storeName) async {
  final current =
      await window.self.indexedDB.open(dbName).asFuture<IDBDatabase>();
  final nextVersion = current.version + 1;
  current.close();
  final request = window.self.indexedDB.open(dbName, nextVersion);
  request.onupgradeneeded = (IDBVersionChangeEvent e) {
    final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
    db.createObjectStore(storeName);
  }.toJS;
  final db = await request.asFuture<IDBDatabase>();
  db.close();
}

Future<bool> _databaseExists(String dbName) async {
  final databases = await window.self.indexedDB.databases().toDart;
  return databases.toDart.any((database) => database.name == dbName);
}

Future<bool> _hasObjectStore(String dbName, String storeName) async {
  final db = await window.self.indexedDB.open(dbName).asFuture<IDBDatabase>();
  final contains = db.objectStoreNames.contains(storeName);
  db.close();
  return contains;
}

void main() {
  group('BackendManager', () {
    group('.open()', () {
      test('creates missing box store in existing database', () async {
        final backendManager = BackendManager.select();
        final boxName =
            'missingstore-${DateTime.timestamp().millisecondsSinceEpoch}';
        await _createDb(boxName);

        final backend = await backendManager
            .open(boxName, null, false, null, null, null)
            .timeout(const Duration(seconds: 5));
        await backend.close();

        expect(await _hasObjectStore(boxName, 'box'), isTrue);
      });

      test('creates missing collection store in existing database', () async {
        final backendManager = BackendManager.select();
        final timestamp = DateTime.timestamp().millisecondsSinceEpoch;
        final collection = 'collection-$timestamp';
        final boxName = 'newbox-$timestamp';
        await _createDb(collection, storeName: 'other');

        final backend = await backendManager
            .open(boxName, null, false, null, null, collection)
            .timeout(const Duration(seconds: 5));
        await backend.close();

        expect(await _hasObjectStore(collection, boxName), isTrue);
      });

      test('reopens a database that a previous open upgraded', () async {
        final backendManager = BackendManager.select();
        final boxName =
            'upgradedstore-${DateTime.timestamp().millisecondsSinceEpoch}';
        await _createDb(boxName);
        final firstBackend = await backendManager
            .open(boxName, null, false, null, null, null)
            .timeout(const Duration(seconds: 5));
        await firstBackend.close();

        final backend = await backendManager
            .open(boxName, null, false, null, null, null)
            .timeout(const Duration(seconds: 5));
        await backend.close();

        expect(await _hasObjectStore(boxName, 'box'), isTrue);
      });

      test('opens a database whose version is above 1', () async {
        final backendManager = BackendManager.select();
        final timestamp = DateTime.timestamp().millisecondsSinceEpoch;
        final collection = 'collection-$timestamp';
        final boxName = 'existingbox-$timestamp';
        await _createDb(collection, storeName: 'other');
        await _addObjectStore(collection, boxName);

        final backend = await backendManager
            .open(boxName, null, false, null, null, collection)
            .timeout(const Duration(seconds: 5));
        await backend.close();

        expect(await _hasObjectStore(collection, boxName), isTrue);
      });
    });

    group('.boxExists()', () {
      test('returns true', () async {
        final backendManager = BackendManager.select();
        final db = await _openDb();
        db.close();
        expect(await backendManager.boxExists('testBox', null, null), isTrue);
      });

      test('returns false', () async {
        final backendManager = BackendManager.select();
        final boxName =
            'notexists-${DateTime.timestamp().millisecondsSinceEpoch}';
        expect(await backendManager.boxExists(boxName, null, null), isFalse);
      });

      test('returns true for a box database above version 1', () async {
        final backendManager = BackendManager.select();
        final boxName =
            'upgradedbox-${DateTime.timestamp().millisecondsSinceEpoch}';
        await _createDb(boxName);
        await _addObjectStore(boxName, 'box');

        expect(await backendManager.boxExists(boxName, null, null), isTrue);
      });

      test('returns false for a database without the box store', () async {
        final backendManager = BackendManager.select();
        final boxName =
            'emptydb-${DateTime.timestamp().millisecondsSinceEpoch}';
        await _createDb(boxName);

        expect(await backendManager.boxExists(boxName, null, null), isFalse);
      });

      test('returns true for a collection box above version 1', () async {
        final backendManager = BackendManager.select();
        final timestamp = DateTime.timestamp().millisecondsSinceEpoch;
        final collection = 'collection-$timestamp';
        final boxName = 'existingbox-$timestamp';
        await _createDb(collection, storeName: 'other');
        await _addObjectStore(collection, boxName);

        expect(
          await backendManager.boxExists(boxName, null, collection),
          isTrue,
        );
      });

      test('does not leave a box database connection open', () async {
        final backendManager = BackendManager.select();
        final boxName =
            'closedbox-${DateTime.timestamp().millisecondsSinceEpoch}';
        await _createDb(boxName, storeName: 'box');
        await backendManager.boxExists(boxName, null, null);

        await _addObjectStore(boxName, 'other')
            .timeout(const Duration(seconds: 5));

        expect(await _hasObjectStore(boxName, 'other'), isTrue);
      });

      test('does not leave a collection connection open', () async {
        final backendManager = BackendManager.select();
        final timestamp = DateTime.timestamp().millisecondsSinceEpoch;
        final collection = 'collection-$timestamp';
        await _createDb(collection, storeName: 'other');
        await backendManager.boxExists('box-$timestamp', null, collection);

        await _addObjectStore(collection, 'added')
            .timeout(const Duration(seconds: 5));

        expect(await _hasObjectStore(collection, 'added'), isTrue);
      });
    });

    group('.deleteBox()', () {
      test('removes a collection store above version 1', () async {
        final backendManager = BackendManager.select();
        final timestamp = DateTime.timestamp().millisecondsSinceEpoch;
        final collection = 'collection-$timestamp';
        final boxName = 'deletedbox-$timestamp';
        await _createDb(collection, storeName: 'other');
        await _addObjectStore(collection, boxName);

        await backendManager
            .deleteBox(boxName, null, collection)
            .timeout(const Duration(seconds: 5));

        expect(await _hasObjectStore(collection, boxName), isFalse);
      });

      test('deletes a collection database left without stores', () async {
        final backendManager = BackendManager.select();
        final timestamp = DateTime.timestamp().millisecondsSinceEpoch;
        final collection = 'collection-$timestamp';
        final boxName = 'deletedbox-$timestamp';
        await _createDb(collection);
        await _addObjectStore(collection, boxName);

        await backendManager
            .deleteBox(boxName, null, collection)
            .timeout(const Duration(seconds: 5));

        expect(await _databaseExists(collection), isFalse);
      });
    });
  });
}
