import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/box_impl.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import '../common.dart';
import '../mocks.dart';

BoxImpl _getBox({
  String? name,
  HiveImpl? hive,
  Keystore? keystore,
  CompactionStrategy? cStrategy,
  StorageBackend? backend,
}) {
  final box = BoxImpl(
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
  group('BoxImpl', () {
    test('.values', () {
      final keystore = Keystore.debug(
        frames: [
          Frame(0, 123),
          Frame('key1', 'value1'),
          Frame(1, null),
        ],
      );
      final box = _getBox(keystore: keystore);

      expect(box.values, [123, null, 'value1']);
    });

    test('.valuesBetween()', () {
      final keystore = Keystore.debug(
        frames: [
          Frame(0, 0),
          Frame(1, 1),
          Frame('0', 2),
          Frame('1', 3),
        ],
      );
      final box = _getBox(keystore: keystore);

      expect(box.valuesBetween(startKey: 1, endKey: '0'), [1, 2]);
    });

    group('.get()', () {
      test('returns defaultValue if key does not exist', () {
        final backend = MockStorageBackend();
        final box = _getBox(backend: backend);

        expect(box.get('someKey'), null);
        expect(box.get('otherKey', defaultValue: -12), -12);
        verifyZeroInteractions(backend);
      });

      test('returns cached value if it exists', () {
        final backend = MockStorageBackend();
        final box = _getBox(
          backend: backend,
          keystore: Keystore.debug(
            frames: [
              Frame('testKey', 'testVal'),
              Frame(123, 456),
            ],
          ),
        );

        expect(box.get('testKey'), 'testVal');
        expect(box.get(123), 456);
        verifyZeroInteractions(backend);
      });
    });

    test('.getAt() returns value at given index', () {
      final keystore =
          Keystore.debug(frames: [Frame(0, 'zero'), Frame('a', 'A')]);
      final box = _getBox(keystore: keystore);

      expect(box.getAt(0), 'zero');
      expect(box.getAt(1), 'A');
    });

    group('.putAll()', () {
      test('detaches HiveObjects when an insertion is rolled back', () async {
        final backend = MockStorageBackend();
        final box = _getBox(backend: backend);
        final object = TestHiveObject();
        final failure = StateError('Backend write failed.');
        when(() => backend.writeFrames(any())).thenThrow(failure);

        await expectLater(box.put('key', object), throwsA(same(failure)));

        expect(box.get('key'), isNull);
        expect(object.key, isNull);
        expect(object.box, isNull);
        expect(object.isInBox, isFalse);
      });

      test('restores HiveObjects when an overwrite is rolled back', () async {
        final backend = MockStorageBackend();
        final box = _getBox(backend: backend);
        final original = TestHiveObject();
        final replacement = TestHiveObject();
        returnFutureVoid(when(() => backend.writeFrames(any())));
        await box.put('key', original);
        final failure = StateError('Backend write failed.');
        when(() => backend.writeFrames(any())).thenThrow(failure);

        await expectLater(box.put('key', replacement), throwsA(same(failure)));

        expect(box.get('key'), same(original));
        expect(original.key, 'key');
        expect(original.box, same(box));
        expect(original.isInBox, isTrue);
        expect(replacement.key, isNull);
        expect(replacement.box, isNull);
        expect(replacement.isInBox, isFalse);
        returnFutureVoid(when(() => backend.writeFrames(any())));
        await original.save();
        expect(box.get('key'), same(original));
      });

      test('values', () async {
        final frames = <Frame>[
          Frame('key1', 'value1'),
          Frame('key2', 'value2'),
        ];
        final keystoreFrames = <Frame>[Frame('keystoreFrames', 123)];

        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        when(() => keystore.frames).thenReturn(keystoreFrames);
        when(() => keystore.beginTransaction(any())).thenReturn(true);
        returnFutureVoid(when(() => backend.writeFrames(frames)));
        returnFutureVoid(when(() => backend.compact(keystoreFrames)));
        when(() => backend.supportsCompaction).thenReturn(true);
        when(() => keystore.length).thenReturn(-1);
        when(() => keystore.deletedEntries).thenReturn(-1);

        final box = _getBox(
          keystore: keystore,
          backend: backend,
          cStrategy: (a, b) => true,
        );

        await box.putAll({'key1': 'value1', 'key2': 'value2'});
        verifyInOrder([
          () => keystore.beginTransaction(frames),
          () => backend.writeFrames(frames),
          keystore.commitTransaction,
          () => backend.compact([Frame('keystoreFrames', 123)]),
        ]);
      });

      test('does nothing if no frames are provided', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        when(() => keystore.beginTransaction([])).thenReturn(false);

        final box = _getBox(backend: backend, keystore: keystore);

        await box.putAll({});
        verify(() => keystore.beginTransaction([]));
        verifyZeroInteractions(backend);
      });

      test('handles exceptions', () async {
        final backend = MockStorageBackend();
        final keystore = MockKeystore();

        when(() => backend.writeFrames(any())).thenThrow('Some error');
        when(() => keystore.beginTransaction(any())).thenReturn(true);

        final box = _getBox(backend: backend, keystore: keystore);

        await expectLater(
          () async => await box.putAll({'key1': 'value1', 'key2': 'value2'}),
          throwsA(anything),
        );
        final frames = [Frame('key1', 'value1'), Frame('key2', 'value2')];
        verifyInOrder([
          () => keystore.beginTransaction(frames),
          () => backend.writeFrames(frames),
          keystore.cancelTransaction,
        ]);
      });
    });

    group('.deleteAll()', () {
      test('restores HiveObjects when a deletion is rolled back', () async {
        final backend = MockStorageBackend();
        final box = _getBox(backend: backend);
        final object = TestHiveObject();
        returnFutureVoid(when(() => backend.writeFrames(any())));
        await box.put('key', object);
        final failure = StateError('Backend write failed.');
        when(() => backend.writeFrames(any())).thenThrow(failure);

        await expectLater(object.delete(), throwsA(same(failure)));

        expect(box.get('key'), same(object));
        expect(object.key, 'key');
        expect(object.box, same(box));
        expect(object.isInBox, isTrue);
        returnFutureVoid(when(() => backend.writeFrames(any())));
        await object.save();
        await object.delete();
        expect(box.get('key'), isNull);
        expect(object.isInBox, isFalse);
      });

      test('do nothing when deleting non existing keys', () async {
        final frames = <Frame>[];

        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        final box = _getBox(backend: backend, keystore: keystore);
        when(() => keystore.frames).thenReturn(frames);
        when(() => keystore.containsKey(any())).thenReturn(false);
        returnFutureVoid(when(() => backend.compact(frames)));
        when(() => keystore.beginTransaction(frames)).thenReturn(false);

        await box.deleteAll(['key1', 'key2', 'key3']);
        verifyZeroInteractions(backend);
      });

      test('delete keys', () async {
        final frames = [Frame.deleted('key1'), Frame.deleted('key2')];

        final backend = MockStorageBackend();
        final keystore = MockKeystore();
        when(() => backend.supportsCompaction).thenReturn(true);
        when(() => keystore.beginTransaction(any())).thenReturn(true);
        returnFutureVoid(when(() => backend.writeFrames(frames)));
        when(() => keystore.containsKey(any())).thenReturn(true);
        when(() => keystore.length).thenReturn(-1);
        when(() => keystore.deletedEntries).thenReturn(-1);
        when(() => keystore.frames).thenReturn(frames);
        returnFutureVoid(when(() => backend.compact(frames)));

        final box = _getBox(
          backend: backend,
          keystore: keystore,
          cStrategy: (a, b) => true,
        );

        await box.deleteAll(['key1', 'key2']);
        verifyInOrder([
          () => keystore.containsKey('key1'),
          () => keystore.containsKey('key2'),
          () => keystore.beginTransaction(frames),
          () => backend.writeFrames(frames),
          keystore.commitTransaction,
          () => backend.compact(any()),
        ]);
      });
    });

    test('.toMap()', () {
      final box = _getBox(
        keystore: Keystore.debug(
          frames: [
            Frame('key1', 1),
            Frame('key2', 2),
            Frame('key4', 444),
          ],
        ),
      );
      expect(box.toMap(), {'key1': 1, 'key2': 2, 'key4': 444});
    });
  });
}
