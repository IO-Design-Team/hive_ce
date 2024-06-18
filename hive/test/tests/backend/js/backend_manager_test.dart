@TestOn('browser')
library;


import 'dart:js_interop';

import 'package:hive_ce/src/backend/js/backend_manager.dart';
import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

Future<IDBDatabase> _openDb() {
  final request = window.self.indexedDB.open('testBox', 1);
  request.onupgradeneeded = (e) {
    final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
    if (!db.objectStoreNames.contains('box')) {
      db.createObjectStore('box');
    }
  }.toJS;
  return request.asFuture<IDBDatabase>();
}

void main() {
  group('BackendManager', () {
    group('.boxExists()', () {
      test('returns true', () async {
        final backendManager = BackendManager.select();
        final db = await _openDb();
        db.close();
        expect(await backendManager.boxExists('testBox', null, null), isTrue);
      });

      test('returns false', () async {
        final backendManager = BackendManager.select();
        final boxName = 'notexists-${DateTime.now().millisecondsSinceEpoch}';
        expect(await backendManager.boxExists(boxName, null, null), isFalse);
      });
    });
  });
}
