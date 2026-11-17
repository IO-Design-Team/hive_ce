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
    });
  });
}
