@TestOn('browser')

import 'dart:async' show Future;
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/backend/js/native/storage_backend_js.dart';
import 'package:hive/src/backend/js/native/utils.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/change_notifier.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/registry/type_registry_impl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

import '../../frames.dart';

late final IDBDatabase _nullDatabase;
StorageBackendJs _getBackend({
  IDBDatabase? db,
  HiveCipher? cipher,
  TypeRegistry registry = TypeRegistryImpl.nullImpl,
}) {
  return StorageBackendJs(db ?? _nullDatabase, cipher, 'box', registry);
}

Future<IDBDatabase> _openDb([String name = 'testBox']) async {
  final request = window.indexedDB.open(name, 1);
  request.onupgradeneeded = (IDBVersionChangeEvent e) {
    var db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
    if (!db.objectStoreNames.contains('box')) {
      db.createObjectStore('box');
    }
  }.toJS;
  return await request.asFuture() as IDBDatabase;
}

IDBObjectStore _getStore(IDBDatabase db) {
  return db.transaction('box'.toJS, 'readwrite').objectStore('box');
}

Future<IDBDatabase> _getDbWith(Map<String, Object?> content) async {
  var db = await _openDb();
  var store = _getStore(db);
  await store.clear().asFuture();
  content.forEach((k, v) => store.put(_toJS(v), k.toJS));
  return db;
}

JSAny? _toJS(Object? value) {
  if (value == null) {
    return null;
  } else if (value is num) {
    return value.toJS;
  } else if (value is bool) {
    return value.toJS;
  } else if (value is String) {
    return value.toJS;
  } else if (value is List<num> ||
      value is List<bool> ||
      value is List<String>) {
    value as List;
    return value.map(_toJS).toList().toJS;
  } else {
    return null;
  }
}

void main() async {
  _nullDatabase = await _openDb('nullTestBox');
  group('StorageBackendJs', () {
    test('.path', () {
      expect(_getBackend().path, null);
    });

    group('.encodeValue()', () {
      test('primitive', () {
        var values = [
          null, 11, 17.25, true, 'hello', //
          [11, 12, 13], [17.25, 17.26], [true, false], ['str1', 'str2'] //
        ];
        var backend = _getBackend();
        for (var i = 0; i < values.length; i++) {
          final value = values[i];
          final encoded = backend.encodeValue(Frame('key', value));
          final expected = _toJS(value);
          if (encoded.isA<JSArray>()) {
            encoded as JSArray;
            expected as JSArray;
            expect(encoded.toDart.length, expected.toDart.length);
            for (var j = 0; j < encoded.toDart.length; j++) {
              expect(encoded.toDart[j], expected.toDart[j]);
            }
          } else {
            expect(encoded.equals(expected).toDart, true);
          }
        }

        var bytes = Uint8List.fromList([1, 2, 3]);
        var buffer = backend.encodeValue(Frame('key', bytes)) as JSArrayBuffer;
        expect(Uint8List.view(buffer.toDart), [1, 2, 3]);
      });

      test('crypto', () {
        var backend =
            StorageBackendJs(_nullDatabase, testCipher, 'box', testRegistry);
        var i = 0;
        for (var frame in testFrames) {
          var buffer = backend.encodeValue(frame) as JSArrayBuffer;
          var bytes = Uint8List.view(buffer.toDart);
          expect(bytes.sublist(28),
              [0x90, 0xA9, ...frameValuesBytesEncrypted[i]].sublist(28));
          i++;
        }
      });

      group('non primitive', () {
        test('map', () {
          var frame = Frame(0, {
            'key': Uint8List.fromList([1, 2, 3]),
            'otherKey': null
          });
          var backend = StorageBackendJs(_nullDatabase, null, 'box');
          var encoded = Uint8List.view(
              (backend.encodeValue(frame) as JSArrayBuffer).toDart);

          var writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl)
            ..write(frame.value);
          expect(encoded, [0x90, 0xA9, ...writer.toBytes()]);
        });

        test('bytes which start with signature', () {
          var frame = Frame(0, Uint8List.fromList([0x90, 0xA9, 1, 2, 3]));
          var backend = _getBackend();
          var encoded = Uint8List.view(
            (backend.encodeValue(frame) as JSArrayBuffer).toDart,
          );

          var writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl)
            ..write(frame.value);
          expect(encoded, [0x90, 0xA9, ...writer.toBytes()]);
        });
      });
    });

    group('.decodeValue()', () {
      test('primitive', () {
        var backend = _getBackend();
        expect(backend.decodeValue(null), null);
        expect(backend.decodeValue(11.toJS), 11);
        expect(backend.decodeValue(17.25.toJS), 17.25);
        expect(backend.decodeValue(true.toJS), true);
        expect(backend.decodeValue('hello'.toJS), 'hello');
        expect(
          backend.decodeValue([11, 12, 13].map((e) => e.toJS).toList().toJS),
          [11, 12, 13],
        );
        expect(
          backend.decodeValue([17.25, 17.26].map((e) => e.toJS).toList().toJS),
          [17.25, 17.26],
        );

        var bytes = Uint8List.fromList([1, 2, 3]);
        expect(backend.decodeValue(bytes.buffer.toJS), [1, 2, 3]);
      });

      test('crypto', () {
        var cipher = HiveAesCipher(Uint8List.fromList(List.filled(32, 1)));
        var backend = _getBackend(cipher: cipher, registry: testRegistry);
        var i = 0;
        for (var testFrame in testFrames) {
          var bytes = [0x90, 0xA9, ...frameValuesBytesEncrypted[i]];
          var value =
              backend.decodeValue(Uint8List.fromList(bytes).buffer.toJS);
          expect(value, testFrame.value);
          i++;
        }
      });

      test('non primitive', () {
        var backend = _getBackend(registry: testRegistry);
        for (var testFrame in testFrames) {
          var bytes = backend.encodeValue(testFrame);
          var value = backend.decodeValue(bytes);
          expect(value, testFrame.value);
        }
      });
    });

    group('.getKeys()', () {
      test(
        'with cursor',
        () async {
          var db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
          var backend = _getBackend(db: db);

          expect(await backend.getKeys(cursor: true), ['key1', 'key2', 'key3']);
        },
        skip: 'Not working',
      );

      test('without cursor', () async {
        var db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
        var backend = _getBackend(db: db);

        expect(await backend.getKeys(), ['key1', 'key2', 'key3']);
      });
    });

    group('.getValues()', () {
      test(
        'with cursor',
        () async {
          var db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
          var backend = _getBackend(db: db);

          expect(await backend.getValues(cursor: true), [1, null, 3]);
        },
        skip: 'Not working',
      );

      test('without cursor', () async {
        var db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        var backend = _getBackend(db: db);

        expect(await backend.getValues(), [1, null, 3]);
      });
    });

    group('.initialize()', () {
      test('not lazy', () async {
        var db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        var backend = _getBackend(db: db);

        var keystore = Keystore.debug(notifier: ChangeNotifier());
        expect(
            await backend.initialize(
                TypeRegistryImpl.nullImpl, keystore, false),
            0);
        expect(keystore.frames, [
          Frame('key1', 1),
          Frame('key2', null),
          Frame('key3', 3),
        ]);
      });

      test('lazy', () async {
        var db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        var backend = _getBackend(db: db);

        var keystore = Keystore.debug(notifier: ChangeNotifier());
        expect(
            await backend.initialize(TypeRegistryImpl.nullImpl, keystore, true),
            0);
        expect(keystore.frames, [
          Frame.lazy('key1'),
          Frame.lazy('key2'),
          Frame.lazy('key3'),
        ]);
      });
    });

    test('.readValue()', () async {
      var db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
      var backend = _getBackend(db: db);

      expect(await backend.readValue(Frame('key1', null)), 1);
      expect(await backend.readValue(Frame('key2', null)), null);
    });

    test('.writeFrames()', () async {
      var db = await _getDbWith({});
      var backend = _getBackend(db: db);

      var frames = [Frame('key1', 123), Frame('key2', null)];
      await backend.writeFrames(frames);
      expect(frames, [Frame('key1', 123), Frame('key2', null)]);
      expect(await backend.getKeys(), ['key1', 'key2']);

      await backend.writeFrames([Frame.deleted('key1')]);
      expect(await backend.getKeys(), ['key2']);
    });

    test('.compact()', () async {
      var db = await _getDbWith({});
      var backend = _getBackend(db: db);
      expect(
        () async => await backend.compact({}),
        throwsUnsupportedError,
      );
    });

    test('.clear()', () async {
      var db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
      var backend = _getBackend(db: db);
      await backend.clear();
      expect(await backend.getKeys(), []);
    });

    test('.close()', () async {
      var db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
      var backend = _getBackend(db: db);
      await backend.close();

      await expectLater(() async => await backend.getKeys(), throwsA(anything));
    });
  });
}
