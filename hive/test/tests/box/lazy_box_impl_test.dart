import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/box/lazy_box_impl.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../common.dart';
import '../mocks.dart';

LazyBoxImpl _getBox({
  String? name,
  HiveImpl? hive,
  Keystore? keystore,
  CompactionStrategy? cStrategy,
  StorageBackend? backend,
}) {
  final box = LazyBoxImpl(
    hive ?? HiveImpl(),
    name ?? 'testBox',
    null,
    cStrategy ?? (total, deleted) => false,
    backend ?? MockStorageBackend(),
  );
  box.keystore = keystore ?? Keystore(box, ChangeNotifier(), null);
  return box;
}

void main() {
  setUpAll(() {
    registerFallbackValue(Frame.deleted(0));
  });

  group('LazyBoxImpl', () {
    group('.get()', () {
      test('returns defaultValue if key does not exist', () async {
        final backend = MockStorageBackend();
        final box = _getBox(backend: backend);

        expect(await box.get('someKey'), null);
        expect(await box.get('otherKey', defaultValue: -12), -12);
        verifyZeroInteractions(backend);
      });

      test('reads value from backend', () async {
        final backend = MockStorageBackend();
        when(() => backend.readValue(any())).thenAnswer((i) async => 'testVal');

        final box = _getBox(backend: backend);
        final frame = Frame.lazy('testKey', length: 123, offset: 456);
        box.keystore.insert(frame);

        expect(await box.get('testKey'), 'testVal');
        verify(() => backend.readValue(frame));
      });
    });

    test('.getAt()', () async {
      final keystore = Keystore.debug(
        frames: [
          Frame.lazy(0),
          Frame.lazy('a'),
        ],
      );
      final backend = MockStorageBackend();
      when(() => backend.readValue(any())).thenAnswer((i) {
        return Future.value('A');
      });
      final box = _getBox(keystore: keystore, backend: backend);

      expect(await box.getAt(1), 'A');
    });

    group('.put()', () {
      test(
          'writes single entry, updates autoIncrement, and initializes HiveObject',
          () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        final keystoreFrames = <Frame>[Frame('keystoreFrames', 123)];
        final obj = TestHiveObject();
        returnFutureVoid(when(() => backend.writeFrames(any())));
        when(() => backend.supportsCompaction).thenReturn(true);
        when(() => keystore.frames).thenReturn(keystoreFrames);
        when(() => keystore.length).thenReturn(-1);
        when(() => keystore.deletedEntries).thenReturn(-1);
        returnFutureVoid(when(() => backend.compact(keystoreFrames)));

        final box = _getBox(
          backend: backend,
          keystore: keystore,
          cStrategy: (a, b) => true,
        );

        await box.put(5, obj);
        expect(obj.key, 5);
        expect(obj.box, box);
        verifyInOrder([
          () => keystore.updateAutoIncrement(5),
          () => backend.writeFrames([Frame(5, obj)]),
          () => keystore.insert(Frame(5, obj), lazy: true),
          () => backend.compact(keystoreFrames),
        ]);
      });

      test('handles exceptions', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        const theError = 'Some error';

        when(() => backend.writeFrames(any())).thenThrow(theError);

        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await expectLater(
          () async => await box.put('key1', 'value1'),
          throwsA(theError),
        );
        verify(() => backend.writeFrames([Frame('key1', 'value1')]));
        verifyNoMoreInteractions(keystore);
      });

      test('throws if box is closed', () async {
        final backend = MockStorageBackend();
        returnFutureVoid(when(backend.close));

        final box = _getBox(backend: backend);
        await box.close();

        await expectLater(
          box.put('key1', 'value1'),
          throwsHiveError(['closed']),
        );
      });
    });

    group('.putAll()', () {
      test('values', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        when(() => keystore.containsKey(any())).thenReturn(false);
        returnFutureVoid(when(() => backend.writeFrames(any())));
        when(() => keystore.length).thenReturn(-1);
        when(() => keystore.deletedEntries).thenReturn(-1);

        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await box.putAll({'key1': 'value1', 'key2': 'value2'});
        verifyInOrder([
          () => backend.writeFrames([
                Frame('key1', 'value1'),
                Frame('key2', 'value2'),
              ]),
          () => keystore.insert(Frame('key1', 'value1'), lazy: true),
          () => keystore.insert(Frame('key2', 'value2'), lazy: true),
        ]);
      });

      test('handles exceptions', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        final theError = 'Some error';

        when(() => backend.writeFrames(any())).thenThrow(theError);
        when(() => keystore.containsKey(any())).thenReturn(true);

        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await expectLater(
          () async => await box.putAll(
            {'key1': 'value1', 'key2': 'value2'},
          ),
          throwsA(theError),
        );
        verify(
          () => backend.writeFrames([
            Frame('key1', 'value1'),
            Frame('key2', 'value2'),
          ]),
        );
        verifyNoMoreInteractions(keystore);
      });
    });

    group('.delete()', () {
      test('does nothing when deleting non existing key', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        when(() => keystore.containsKey('key1')).thenReturn(false);
        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await box.delete('key1');
        verify(() => keystore.containsKey('key1'));
        verifyZeroInteractions(backend);
      });

      test('deletes existing key', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        final keystoreFrames = <Frame>[Frame('keystoreFrames', 123)];
        when(() => keystore.containsKey('key1')).thenReturn(true);
        returnFutureVoid(when(() => backend.writeFrames(any())));
        when(() => backend.supportsCompaction).thenReturn(true);
        when(() => keystore.frames).thenReturn(keystoreFrames);
        when(() => keystore.length).thenReturn(-1);
        when(() => keystore.deletedEntries).thenReturn(-1);
        returnFutureVoid(when(() => backend.compact(keystoreFrames)));

        final box = _getBox(
          backend: backend,
          keystore: keystore,
          cStrategy: (a, b) => true,
        );

        await box.delete('key1');
        verifyInOrder([
          () => keystore.containsKey('key1'),
          () => backend.writeFrames([Frame.deleted('key1')]),
          () => keystore.insert(Frame.deleted('key1')),
          () => backend.compact(keystoreFrames),
        ]);
      });

      test('throws if box is closed', () async {
        final backend = MockStorageBackend();
        returnFutureVoid(when(backend.close));

        final box = _getBox(backend: backend);
        await box.close();

        await expectLater(
          box.delete('key1'),
          throwsHiveError(['closed']),
        );
      });
    });

    group('.deleteAll()', () {
      test('does nothing when deleting non existing keys', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        when(() => keystore.containsKey(any())).thenReturn(false);
        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await box.deleteAll(['key1', 'key2', 'key3']);
        verifyZeroInteractions(backend);
      });

      test('delete keys', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        when(() => keystore.containsKey(any())).thenReturn(true);
        returnFutureVoid(when(() => backend.writeFrames(any())));
        when(() => keystore.length).thenReturn(-1);
        when(() => keystore.deletedEntries).thenReturn(-1);

        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await box.deleteAll(['key1', 'key2']);
        verifyInOrder([
          () => keystore.containsKey('key1'),
          () => keystore.containsKey('key2'),
          () => backend
              .writeFrames([Frame.deleted('key1'), Frame.deleted('key2')]),
          () => keystore.insert(Frame.deleted('key1')),
          () => keystore.insert(Frame.deleted('key2')),
        ]);
      });
    });
  });
}
