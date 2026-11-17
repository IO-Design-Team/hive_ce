@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/backend/js/native/storage_backend_js.dart';
import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
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
  final request = window.self.indexedDB.open(name, 1);
  request.onupgradeneeded = (IDBVersionChangeEvent e) {
    final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
    if (!db.objectStoreNames.contains('box')) {
      db.createObjectStore('box');
    }
  }.toJS;
  return await request.asFuture<IDBDatabase>();
}

IDBObjectStore _getStore(IDBDatabase db) {
  return db.transaction('box'.toJS, 'readwrite').objectStore('box');
}

Future<IDBDatabase> _getDbWith(Map<String, Object?> content) async {
  final db = await _openDb();
  final store = _getStore(db);
  await store.clear().asFuture();
  content.forEach((k, v) => store.put(v.jsify(), k.toJS));
  return db;
}

/// A database whose box rejects a value that another key already holds. A put
/// can then fail on its own, after it was queued.
Future<IDBDatabase> _getDbWithUniqueValues() async {
  final request = window.self.indexedDB.open('uniqueValuesTestBox', 1);
  request.onupgradeneeded = (IDBVersionChangeEvent e) {
    final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
    db
        .createObjectStore('box')
        .createIndex('value', ''.toJS, IDBIndexParameters(unique: true));
  }.toJS;
  final db = await request.asFuture<IDBDatabase>();
  await _getStore(db).clear().asFuture();
  return db;
}

/// The IndexedDB error that [write] fails with.
Future<DOMException> _errorOf(Future<void> write) async {
  try {
    await write;
  } catch (e) {
    return e as DOMException;
  }
  fail('The write did not fail.');
}

class _AwaitFromHere {
  const _AwaitFromHere();
}

/// Makes `writeFrames` await the request of the frame it encodes.
class _AwaitFromHereAdapter extends TypeAdapter<_AwaitFromHere> {
  @override
  final typeId = 0;

  @override
  _AwaitFromHere read(BinaryReader reader) => const _AwaitFromHere();

  @override
  void write(BinaryWriter writer, _AwaitFromHere obj) {
    StorageBackendJs.writeSlice = Duration.zero;
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
        final values = [null, 17.25, true, 'hello'];
        final backend = _getBackend();
        for (final value in values) {
          expect(backend.encodeValue(Frame('key', value)).dartify(), value);
        }

        final bytes = Uint8List.fromList([1, 2, 3]);
        final buffer =
            backend.encodeValue(Frame('key', bytes)) as JSArrayBuffer;
        expect(Uint8List.view(buffer.toDart), [1, 2, 3]);
      });

      test('crypto', () {
        final backend =
            StorageBackendJs(_nullDatabase, testCipher, 'box', testRegistry);
        var i = 0;
        for (final frame in testFrames) {
          final buffer = backend.encodeValue(frame) as JSArrayBuffer;
          final bytes = Uint8List.view(buffer.toDart);
          expect(
            bytes.sublist(28),
            [0x90, 0xA9, ...frameValuesBytesEncrypted[i]].sublist(28),
          );
          i++;
        }
      });

      group('non primitive', () {
        test('map', () {
          final frame = Frame(0, {
            'key': Uint8List.fromList([1, 2, 3]),
            'otherKey': null,
          });
          final backend = StorageBackendJs(_nullDatabase, null, 'box');
          final encoded = Uint8List.view(
            (backend.encodeValue(frame) as JSArrayBuffer).toDart,
          );

          final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl)
            ..write(frame.value);
          expect(encoded, [0x90, 0xA9, ...writer.toBytes()]);
        });

        test('bytes which start with signature', () {
          final frame = Frame(0, Uint8List.fromList([0x90, 0xA9, 1, 2, 3]));
          final backend = _getBackend();
          final encoded = Uint8List.view(
            (backend.encodeValue(frame) as JSArrayBuffer).toDart,
          );

          final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl)
            ..write(frame.value);
          expect(encoded, [0x90, 0xA9, ...writer.toBytes()]);
        });
      });
    });

    group('.decodeValue()', () {
      test('primitive', () {
        final backend = _getBackend();
        expect(backend.decodeValue(null), null);
        expect(backend.decodeValue(11.toJS), 11);
        expect(backend.decodeValue(17.25.toJS), 17.25);
        expect(backend.decodeValue(true.toJS), true);
        expect(backend.decodeValue('hello'.toJS), 'hello');
        expect(backend.decodeValue([11, 12, 13].jsify()), [11, 12, 13]);
        expect(backend.decodeValue([17.25, 17.26].jsify()), [17.25, 17.26]);

        final bytes = Uint8List.fromList([1, 2, 3]);
        expect(backend.decodeValue(bytes.buffer.toJS), [1, 2, 3]);
      });

      test('crypto', () {
        final cipher = HiveAesCipher(Uint8List.fromList(List.filled(32, 1)));
        final backend = _getBackend(cipher: cipher, registry: testRegistry);
        var i = 0;
        for (final testFrame in testFrames) {
          final bytes = [0x90, 0xA9, ...frameValuesBytesEncrypted[i]];
          final value =
              backend.decodeValue(Uint8List.fromList(bytes).buffer.toJS);
          expect(value, testFrame.value);
          i++;
        }
      });

      test('non primitive', () {
        final backend = _getBackend(registry: testRegistry);
        for (final testFrame in testFrames) {
          final bytes = backend.encodeValue(testFrame);
          final value = backend.decodeValue(bytes);
          expect(value, testFrame.value);

          // Ensure int and List<int> are not decoded as doubles
          if (testFrame.value is! Uint8List &&
              (testFrame.value is int || testFrame.value is List<int>)) {
            expect(value.runtimeType, testFrame.value.runtimeType);
          }
        }
      });
    });

    group('.getKeys()', () {
      test('with cursor', () async {
        final db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
        final backend = _getBackend(db: db);

        expect(await backend.getKeys(cursor: true), ['key1', 'key2', 'key3']);
      });

      test('without cursor', () async {
        final db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
        final backend = _getBackend(db: db);

        expect(await backend.getKeys(), ['key1', 'key2', 'key3']);
      });
    });

    group('.getValues()', () {
      test('with cursor', () async {
        final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        final backend = _getBackend(db: db);

        expect(await backend.getValues(cursor: true), [1, null, 3]);
      });

      test('with cursor decodes encoded values', () async {
        final db = await _getDbWith({});
        final backend = _getBackend(db: db);
        await backend.writeFrames([
          Frame('key1', 1),
          Frame('key2', ['a', 'b']),
        ]);

        final values = await backend.getValues(cursor: true);
        expect(values, [
          1,
          ['a', 'b'],
        ]);
        expect(values.last, isA<List<String>>());
      });

      test('without cursor', () async {
        final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        final backend = _getBackend(db: db);

        expect(await backend.getValues(), [1, null, 3]);
      });
    });

    group('.initialize()', () {
      test('not lazy', () async {
        final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        final backend = _getBackend(db: db);

        final keystore = Keystore.debug(notifier: ChangeNotifier());
        expect(
          await backend.initialize(
            TypeRegistryImpl.nullImpl,
            keystore,
            false,
          ),
          0,
        );
        expect(keystore.frames, [
          Frame('key1', 1),
          Frame('key2', null),
          Frame('key3', 3),
        ]);
      });

      test('lazy', () async {
        final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        final backend = _getBackend(db: db);

        final keystore = Keystore.debug(notifier: ChangeNotifier());
        expect(
          await backend.initialize(TypeRegistryImpl.nullImpl, keystore, true),
          0,
        );
        expect(keystore.frames, [
          Frame.lazy('key1'),
          Frame.lazy('key2'),
          Frame.lazy('key3'),
        ]);
      });
    });

    test('.readValue()', () async {
      final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
      final backend = _getBackend(db: db);

      expect(await backend.readValue(Frame('key1', null)), 1);
      expect(await backend.readValue(Frame('key2', null)), null);
    });

    test('.writeFrames()', () async {
      final db = await _getDbWith({});
      final backend = _getBackend(db: db);

      final frames = [Frame('key1', 123), Frame('key2', null)];
      await backend.writeFrames(frames);
      expect(frames, [Frame('key1', 123), Frame('key2', null)]);
      expect(await backend.getKeys(), ['key1', 'key2']);

      await backend.writeFrames([Frame.deleted('key1')]);
      expect(await backend.getKeys(), ['key2']);
    });

    test('.writeFrames() with no frames', () async {
      final db = await _getDbWith({'key1': 1});
      final backend = _getBackend(db: db);

      await backend.writeFrames([]);
      expect(await backend.getKeys(), ['key1']);
    });

    test('.writeFrames() applies the frames of a batch in order', () async {
      final db = await _getDbWith({});
      final backend = _getBackend(db: db);

      await backend.writeFrames([
        Frame('key1', 'first'),
        Frame('key2', 'gone'),
        Frame('key1', 'second'),
        Frame.deleted('key2'),
        Frame('key3', 'third'),
      ]);
      expect(await backend.getKeys(), ['key1', 'key3']);
      expect(await backend.getValues(), ['second', 'third']);
    });

    test('.writeFrames() writes a large batch', () async {
      final db = await _getDbWith({});
      final backend = _getBackend(db: db);

      final frames = [for (var i = 0; i < 5000; i++) Frame(i, 'value $i')];
      await backend.writeFrames(frames);
      expect(await backend.getKeys(), [for (var i = 0; i < 5000; i++) i]);
      expect(
        await backend.getValues(),
        [for (var i = 0; i < 5000; i++) 'value $i'],
      );
    });

    group('.writeFrames() awaiting every request', () {
      late Duration slice;

      setUp(() {
        slice = StorageBackendJs.writeSlice;
        StorageBackendJs.writeSlice = Duration.zero;
      });

      tearDown(() => StorageBackendJs.writeSlice = slice);

      test('applies the frames of a batch in order', () async {
        final db = await _getDbWith({});
        final backend = _getBackend(db: db);

        await backend.writeFrames([
          Frame('key1', 'first'),
          Frame('key2', 'gone'),
          Frame('key1', 'second'),
          Frame.deleted('key2'),
          Frame('key3', 'third'),
        ]);
        expect(await backend.getKeys(), ['key1', 'key3']);
        expect(await backend.getValues(), ['second', 'third']);
      });

      test('keeps nothing of a batch that fails', () async {
        final db = await _getDbWith({'key1': 'before'});
        final backend = _getBackend(db: db);

        await expectLater(
          backend.writeFrames([
            Frame('key1', 'replaced'),
            Frame('key2', 'added'),
            Frame('key3', Object()),
            Frame('key4', 'never queued'),
          ]),
          throwsA(anything),
        );
        expect(await backend.getKeys(), ['key1']);
        expect(await backend.getValues(), ['before']);

        await backend.writeFrames([Frame('key2', 'after')]);
        expect(await backend.getKeys(), ['key1', 'key2']);
        expect(await backend.getValues(), ['before', 'after']);
      });
    });

    group('.writeFrames() with a request that fails on its own', () {
      late Duration slice;

      setUp(() => slice = StorageBackendJs.writeSlice);

      tearDown(() => StorageBackendJs.writeSlice = slice);

      test('reports the error of that request', () async {
        final db = await _getDbWithUniqueValues();
        final backend = _getBackend(db: db);

        // The second put breaks the unique index after it was queued.
        final error = await _errorOf(
          backend.writeFrames([Frame('key1', 'same'), Frame('key2', 'same')]),
        );
        expect(error.name, 'ConstraintError');
        expect(await backend.getKeys(), isEmpty);
      });

      test('reports the error of that request while it awaits a later one',
          () async {
        final db = await _getDbWithUniqueValues();
        final registry = TypeRegistryImpl()
          ..registerAdapter(_AwaitFromHereAdapter());
        final backend = _getBackend(db: db, registry: registry);

        // No request is awaited until the third frame is encoded. Its request
        // is awaited while the second put breaks the unique index.
        StorageBackendJs.writeSlice = const Duration(hours: 1);
        final error = await _errorOf(
          backend.writeFrames([
            Frame('key1', 'same'),
            Frame('key2', 'same'),
            Frame('key3', const _AwaitFromHere()),
            Frame('key4', 'last'),
          ]),
        );
        expect(error.name, 'ConstraintError');
        expect(await backend.getKeys(), isEmpty);

        // The backend still takes writes afterwards.
        StorageBackendJs.writeSlice = slice;
        await backend.writeFrames([Frame('key1', 'after')]);
        expect(await backend.getKeys(), ['key1']);
      });
    });

    test('.writeFrames() keeps nothing of a batch that fails', () async {
      final db = await _getDbWith({'key1': 'before'});
      final backend = _getBackend(db: db);

      // The third frame cannot be encoded, after two frames were queued.
      await expectLater(
        backend.writeFrames([
          Frame('key1', 'replaced'),
          Frame('key2', 'added'),
          Frame('key3', Object()),
          Frame('key4', 'never queued'),
        ]),
        throwsA(anything),
      );
      expect(await backend.getKeys(), ['key1']);
      expect(await backend.getValues(), ['before']);

      // The backend still takes writes afterwards.
      await backend.writeFrames([Frame('key2', 'after')]);
      expect(await backend.getKeys(), ['key1', 'key2']);
      expect(await backend.getValues(), ['before', 'after']);
    });

    test('.compact()', () async {
      final db = await _getDbWith({});
      final backend = _getBackend(db: db);
      expect(
        () async => await backend.compact({}),
        throwsUnsupportedError,
      );
    });

    test('.clear()', () async {
      final db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
      final backend = _getBackend(db: db);
      await backend.clear();
      expect(await backend.getKeys(), []);
    });

    test('.close()', () async {
      final db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
      final backend = _getBackend(db: db);
      await backend.close();

      await expectLater(() async => await backend.getKeys(), throwsA(anything));
    });
  });
}
