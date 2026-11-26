@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

Future<IDBDatabase> _openDb() {
  final request = window.self.indexedDB.open('utilsTestBox', 1);
  request.onupgradeneeded = (IDBVersionChangeEvent e) {
    final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
    if (!db.objectStoreNames.contains('box')) {
      db.createObjectStore('box');
    }
  }.toJS;
  return request.asFuture<IDBDatabase>();
}

IDBTransaction _txn(IDBDatabase db, [String mode = 'readwrite']) =>
    db.transaction('box'.toJS, mode);

Future<String?> _get(IDBDatabase db, String key) async {
  final value = await _txn(db, 'readonly')
      .objectStore('box')
      .get(key.toJS)
      .asFuture<JSString?>();
  return value?.toDart;
}

void main() async {
  final db = await _openDb();

  group('IDBTransactionExtension', () {
    setUp(() => _txn(db).objectStore('box').clear().asFuture());

    group('.asFuture()', () {
      test('completes on commit', () async {
        final txn = _txn(db);
        txn.objectStore('box').put('value'.toJS, 'key'.toJS);
        await txn.asFuture();

        expect(await _get(db, 'key'), 'value');
      });

      test('fails with request error on abort', () async {
        final txn = _txn(db);
        txn.objectStore('box')
          ..add('first'.toJS, 'dup'.toJS)
          ..add('second'.toJS, 'dup'.toJS);

        await expectLater(
          txn.asFuture(),
          throwsA(
            isA<DOMException>()
                .having((e) => e.name, 'name', 'ConstraintError'),
          ),
        );
        expect(await _get(db, 'dup'), isNull);
      });

      test('fails with StateError when manually aborted', () async {
        final txn = _txn(db);
        final future = txn.asFuture();
        txn.abort();

        await expectLater(future, throwsStateError);
      });
    });

    group('.run()', () {
      test('commits action', () async {
        final txn = _txn(db);
        await txn.run(() {
          txn.objectStore('box')
            ..put('v1'.toJS, 'k1'.toJS)
            ..put('v2'.toJS, 'k2'.toJS);
        });

        expect(await _get(db, 'k1'), 'v1');
        expect(await _get(db, 'k2'), 'v2');
      });

      test('aborts and rethrows on sync error', () async {
        await _txn(db)
            .objectStore('box')
            .put('before'.toJS, 'key'.toJS)
            .asFuture();

        final txn = _txn(db);
        await expectLater(
          txn.run(() {
            txn.objectStore('box').put('after'.toJS, 'key'.toJS);
            throw StateError('sync failure');
          }),
          throwsStateError,
        );
        expect(await _get(db, 'key'), 'before');
      });
    });
  });
}
