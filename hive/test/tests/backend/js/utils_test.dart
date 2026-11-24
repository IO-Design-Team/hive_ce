@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

void _closeDb(IDBDatabase db) => db.close();

Future<IDBDatabase> _openDb() async {
  final request = window.self.indexedDB.open('utilsTestBox', 1);
  request.onupgradeneeded = (IDBVersionChangeEvent e) {
    final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
    if (!db.objectStoreNames.contains('box')) {
      db.createObjectStore('box');
    }
  }.toJS;
  final db = await request.asFuture<IDBDatabase>();
  addTearDown(() => _closeDb(db));
  await db
      .transaction('box'.toJS, 'readwrite')
      .objectStore('box')
      .clear()
      .asFuture();
  return db;
}

void main() {
  group('IDBTransactionExtension', () {
    test('.asFuture() completes when transaction commits', () async {
      final db = await _openDb();
      final txn = db.transaction('box'.toJS, 'readwrite');
      txn.objectStore('box').put('value'.toJS, 'key'.toJS);
      await txn.asFuture();

      final stored = await db
          .transaction('box'.toJS, 'readonly')
          .objectStore('box')
          .get('key'.toJS)
          .asFuture<JSString?>();
      expect(stored?.toDart, 'value');
    });

    test('.asFuture() completes with request error on failure', () async {
      final db = await _openDb();
      final txn = db.transaction('box'.toJS, 'readwrite');
      final store = txn.objectStore('box');
      store.add('first'.toJS, 'dup'.toJS);
      store.add('second'.toJS, 'dup'.toJS);

      try {
        await txn.asFuture();
        fail('Expected transaction to fail with ConstraintError');
      } catch (e) {
        expect((e as DOMException).name, 'ConstraintError');
      }

      final keys = await db
          .transaction('box'.toJS, 'readonly')
          .objectStore('box')
          .getAllKeys(null)
          .asFuture<JSArray>();
      expect(keys.toDart, isEmpty);
    });

    test(
      '.asFuture() completes with StateError when aborted without requests',
      () async {
        final db = await _openDb();
        final txn = db.transaction('box'.toJS, 'readwrite');
        final future = txn.asFuture();
        txn.abort();

        await expectLater(future, throwsA(isA<StateError>()));
      },
    );

    test('.run() executes action and commits', () async {
      final db = await _openDb();
      final txn = db.transaction('box'.toJS, 'readwrite');
      await txn.run(() {
        final store = txn.objectStore('box');
        store.put('v1'.toJS, 'k1'.toJS);
        store.put('v2'.toJS, 'k2'.toJS);
      });

      final readStore =
          db.transaction('box'.toJS, 'readonly').objectStore('box');
      final v1 = await readStore.get('k1'.toJS).asFuture<JSString?>();
      final v2 = await readStore.get('k2'.toJS).asFuture<JSString?>();
      expect(v1?.toDart, 'v1');
      expect(v2?.toDart, 'v2');
    });

    test('.run() aborts transaction and rethrows on synchronous error',
        () async {
      final db = await _openDb();
      await db
          .transaction('box'.toJS, 'readwrite')
          .objectStore('box')
          .put('before'.toJS, 'existing'.toJS)
          .asFuture();

      final txn = db.transaction('box'.toJS, 'readwrite');
      await expectLater(
        txn.run(() {
          txn.objectStore('box').put('after'.toJS, 'existing'.toJS);
          throw StateError('sync failure');
        }),
        throwsA(isA<StateError>()),
      );

      final stored = await db
          .transaction('box'.toJS, 'readonly')
          .objectStore('box')
          .get('existing'.toJS)
          .asFuture<JSString?>();
      expect(stored?.toDart, 'before');
    });
  });
}
