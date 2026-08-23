// This is a test
// ignore_for_file: rexios_lints/prefer_async_await
@TestOn('vm')
library;

import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/adapters/date_time_adapter.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import 'common.dart';

/// A value whose adapter writes fine but refuses to read one particular record back.
class _Flaky {
  const _Flaky(this.id);
  final String id;
}

class _FlakyAdapter extends TypeAdapter<_Flaky> {
  @override
  final typeId = 1;

  @override
  _Flaky read(BinaryReader reader) {
    final id = reader.readString();
    if (id == 'bad') throw const FormatException('cannot decode this record');
    return _Flaky(id);
  }

  @override
  void write(BinaryWriter writer, _Flaky obj) => writer.writeString(obj.id);
}

class _TestAdapter extends TypeAdapter<int> {
  const _TestAdapter([this.typeId = 0]);

  @override
  final int typeId;

  @override
  int read(_) => 5;

  @override
  void write(_, __) {}
}

void main() {
  group('HiveImpl', () {
    Future<HiveImpl> initHive() async {
      final tempDir = await getTempDir();
      final hive = HiveImpl();
      hive.init(tempDir.path);
      return hive;
    }

    test('.init()', () {
      final hive = HiveImpl();

      expect(() => hive.init('MYPATH'), returnsNormally);
      expect(hive.homePath, 'MYPATH');

      final dateTimeAdapter =
          expectNotNull(hive.findAdapterForValue(DateTime.timestamp()));
      expect(dateTimeAdapter.adapter, isA<DateTimeWithTimezoneAdapter>());

      final typeIdAdapter = expectNotNull(hive.findAdapterForTypeId(16));
      expect(typeIdAdapter.adapter, isA<DateTimeAdapter>());
    });

    group('.openBox()', () {
      group('box already open', () {
        test('opened box is returned if it exists', () async {
          final hive = await initHive();

          final testBox = await hive.openBox('TESTBOX');
          final testBox2 = await hive.openBox('testBox');
          expect(testBox == testBox2, true);

          await hive.close();
        });

        test('throw HiveError if opened box is lazy', () async {
          final hive = await initHive();

          await hive.openLazyBox('LAZYBOX');
          await expectLater(
            () => hive.openBox('lazyBox'),
            throwsHiveError(['is already open and of type LazyBox<dynamic>']),
          );

          await hive.close();
        });

        test('throw HiveError if already opening box is lazy', () async {
          final hive = await initHive();

          await Future.wait([
            hive.openLazyBox('TESTBOX'),
            expectLater(
              hive.openBox('testbox'),
              throwsHiveError(['is already open and of type LazyBox<dynamic>']),
            ),
          ]);
        });

        test('same box returned if it is already opening', () async {
          final hive = await initHive();

          Box? box1;
          Box? box2;
          await Future.wait([
            hive.openBox('TESTBOX').then((value) => box1 = value),
            hive.openBox('testbox').then((value) => box2 = value),
          ]);

          expect(box1 == box2, true);
        });
      });

      group('typed map or iterable', () {
        test('throws AssertionError if map or iterable is typed', () async {
          final hive = await initHive();

          expect(
            hive.openBox<Map<String, dynamic>>('mapbox'),
            throwsA(isA<AssertionError>()),
          );
          expect(hive.openBox<Map>('mapbox'), completes);

          Future<void> openBox<T>() async {
            final box = await hive.openBox<T>('iterablebox');
            await box.close();
          }

          expect(
            hive.openBox<Iterable<DateTime>>('iterablebox'),
            throwsA(isA<AssertionError>()),
          );
          await expectLater(openBox<Iterable>(), completes);
          await expectLater(openBox<Iterable<int>>(), completes);
          await expectLater(openBox<Iterable<double>>(), completes);
          await expectLater(openBox<Iterable<bool>>(), completes);
          await expectLater(openBox<Iterable<String>>(), completes);

          expect(
            hive.openBox<List<DateTime>>('listbox'),
            throwsA(isA<AssertionError>()),
          );

          await expectLater(openBox<List>(), completes);
          await expectLater(openBox<List<int>>(), completes);
          await expectLater(openBox<List<double>>(), completes);
          await expectLater(openBox<List<bool>>(), completes);
          await expectLater(openBox<List<String>>(), completes);

          expect(
            hive.openBox<Set<DateTime>>('setbox'),
            throwsA(isA<AssertionError>()),
          );
          await expectLater(openBox<Set>(), completes);
          await expectLater(openBox<Set<int>>(), completes);
          await expectLater(openBox<Set<double>>(), completes);
          await expectLater(openBox<Set<bool>>(), completes);
          await expectLater(openBox<Set<String>>(), completes);
        });
      });

      group('undecodable values', () {
        Future<HiveImpl> seeded() async {
          final hive = await initHive();
          hive.registerAdapter(_FlakyAdapter());
          final box = await hive.openBox<_Flaky>('flaky');
          await box.put('a', const _Flaky('a'));
          await box.put('b', const _Flaky('bad'));
          await box.put('c', const _Flaky('c'));
          await hive.close();
          return hive;
        }

        test('without a handler the open still fails, as before', () async {
          final hive = await seeded();

          await expectLater(
            hive.openBox<_Flaky>('flaky'),
            throwsA(isA<FormatException>()),
          );
        });

        test('with a handler the bad record is skipped and reported', () async {
          final hive = await seeded();
          final reported = <Object>[];

          final box = await hive.openBox<_Flaky>(
            'flaky',
            onUndecodableValue: (key, error, _) {
              reported.add(key);
              expect(error, isA<FormatException>());
            },
          );

          expect(reported, ['b']);
          expect(box.keys, ['a', 'c']);
          expect(box.values.map((value) => value.id), ['a', 'c']);
          // Dropped from the keystore entirely, not left behind as a null.
          expect(box.containsKey('b'), isFalse);
        });

        test('throwing from the handler aborts the open', () async {
          final hive = await seeded();

          await expectLater(
            hive.openBox<_Flaky>(
              'flaky',
              onUndecodableValue: (key, error, stackTrace) =>
                  Error.throwWithStackTrace(error, stackTrace),
            ),
            throwsA(isA<FormatException>()),
          );
        });

        test('a clean box never calls the handler', () async {
          final hive = await initHive();
          hive.registerAdapter(_FlakyAdapter());
          final seed = await hive.openBox<_Flaky>('clean');
          await seed.put('a', const _Flaky('a'));
          await hive.close();

          var called = 0;
          final box = await hive.openBox<_Flaky>(
            'clean',
            onUndecodableValue: (_, __, ___) => called++,
          );

          expect(called, 0);
          expect(box.keys, ['a']);
        });
      });
    });

    group('.openLazyBox()', () {
      group('box already open', () {
        test('opened box is returned if it exists', () async {
          final hive = await initHive();

          final testBox = await hive.openLazyBox('TESTBOX');
          final testBox2 = await hive.openLazyBox('testBox');
          expect(testBox == testBox2, true);

          await hive.close();
        });

        test('same box returned if it is already opening', () async {
          LazyBox? box1;
          LazyBox? box2;

          final hive = await initHive();
          await Future.wait([
            hive.openLazyBox('LAZYBOX').then((value) => box1 = value),
            hive.openLazyBox('lazyBox').then((value) => box2 = value),
          ]);

          expect(box1 == box2, true);
        });

        test('throw HiveError if opened box is not lazy', () async {
          final hive = await initHive();

          await hive.openBox('LAZYBOX');
          await expectLater(
            () => hive.openLazyBox('lazyBox'),
            throwsHiveError(['is already open and of type Box<dynamic>']),
          );

          await hive.close();
        });

        test('throw HiveError if already opening box is not lazy', () async {
          final hive = await initHive();

          await Future.wait([
            hive.openBox('LAZYBOX'),
            expectLater(
              hive.openLazyBox('lazyBox'),
              throwsHiveError(['is already open and of type Box<dynamic>']),
            ),
          ]);
        });
      });
    });

    group('.box()', () {
      test('returns already opened box', () async {
        final hive = await initHive();

        final box = await hive.openBox('TESTBOX');
        expect(hive.box('testBox'), box);
        expect(() => hive.box('other'), throwsHiveError(['not found']));

        await hive.close();
      });

      test('throws HiveError if box type does not match', () async {
        final hive = await initHive();

        await hive.openBox<int>('INTBOX');
        expect(
          () => hive.box('intBox'),
          throwsHiveError(['is already open and of type Box<int>']),
        );

        await hive.openBox('DYNAMICBOX');
        expect(
          () => hive.box<int>('dynamicBox'),
          throwsHiveError(['is already open and of type Box<dynamic>']),
        );

        await hive.openLazyBox('LAZYBOX');
        expect(
          () => hive.box('lazyBox'),
          throwsHiveError(['is already open and of type LazyBox<dynamic>']),
        );

        await hive.close();
      });
    });

    group('.lazyBox()', () {
      test('returns already opened box', () async {
        final hive = await initHive();

        final box = await hive.openLazyBox('TESTBOX');
        expect(hive.lazyBox('testBox'), box);
        expect(() => hive.lazyBox('other'), throwsHiveError(['not found']));

        await hive.close();
      });

      test('throws HiveError if box type does not match', () async {
        final hive = await initHive();

        await hive.openLazyBox<int>('INTBOX');
        expect(
          () => hive.lazyBox('intBox'),
          throwsHiveError(['is already open and of type LazyBox<int>']),
        );

        await hive.openLazyBox('DYNAMICBOX');
        expect(
          () => hive.lazyBox<int>('dynamicBox'),
          throwsHiveError(['is already open and of type LazyBox<dynamic>']),
        );

        await hive.openBox('BOX');
        expect(
          () => hive.lazyBox('box'),
          throwsHiveError(['is already open and of type Box<dynamic>']),
        );

        await hive.close();
      });
    });

    test('isBoxOpen()', () async {
      final hive = await initHive();

      await hive.openBox('testBox');

      expect(hive.isBoxOpen('testBox'), true);
      expect(hive.isBoxOpen('nonExistingBox'), false);

      await hive.close();
    });

    test('.close()', () async {
      final hive = await initHive();

      final box1 = await hive.openBox('box1');
      final box2 = await hive.openBox('box2');
      expect(box1.isOpen, true);
      expect(box2.isOpen, true);

      await hive.close();
      expect(box1.isOpen, false);
      expect(box2.isOpen, false);
    });

    test('.generateSecureKey()', () {
      final hive = HiveImpl();

      final key1 = hive.generateSecureKey();
      final key2 = hive.generateSecureKey();

      expect(key1.length, 32);
      expect(key2.length, 32);
      expect(key1, isNot(key2));
    });

    group('.deleteBoxFromDisk()', () {
      test('deletes open box', () async {
        final hive = await initHive();

        final box1 = await hive.openBox('testBox1');
        await box1.put('key', 'value');
        final box1Path = expectNotNull(box1.path);
        final box1File = File(box1Path);

        await hive.deleteBoxFromDisk('testBox1');
        expect(await box1File.exists(), false);
        expect(hive.isBoxOpen('testBox1'), false);

        await hive.close();
      });

      test('deletes closed box', () async {
        final hive = await initHive();

        final box1 = await hive.openBox('testBox1');
        await box1.put('key', 'value');
        final path = expectNotNull(box1.path);
        await box1.close();
        final box1File = File(path);

        await hive.deleteBoxFromDisk('testBox1');
        expect(await box1File.exists(), false);
        expect(hive.isBoxOpen('testBox1'), false);

        await hive.close();
      });

      test('does nothing if files do not exist', () async {
        final hive = await initHive();
        await hive.deleteBoxFromDisk('testBox1');
        await hive.close();
      });
    });

    test('.deleteFromDisk()', () async {
      final hive = await initHive();

      final box1 = await hive.openBox('testBox1');
      await box1.put('key', 'value');
      final box1Path = expectNotNull(box1.path);
      final box1File = File(box1Path);

      final box2 = await hive.openBox('testBox2');
      await box2.put('key', 'value');
      final box2Path = expectNotNull(box2.path);
      final box2File = File(box2Path);

      await hive.deleteFromDisk();
      expect(await box1File.exists(), false);
      expect(await box2File.exists(), false);
      expect(hive.isBoxOpen('testBox1'), false);
      expect(hive.isBoxOpen('testBox2'), false);

      await hive.close();
    });

    group('.boxExists()', () {
      test('returns true if a box was created', () async {
        final hive = await initHive();
        await hive.openBox('testBox1');
        expect(await hive.boxExists('testBox1'), true);
        await hive.close();
      });

      test('returns false if no box was created', () async {
        final hive = await initHive();
        expect(await hive.boxExists('testBox1'), false);
        await hive.close();
      });

      test('returns false if box was created and then deleted', () async {
        final hive = await initHive();
        await hive.openBox('testBox1');
        await hive.deleteBoxFromDisk('testBox1');
        expect(await hive.boxExists('testBox1'), false);
        await hive.close();
      });
    });

    group('.resetAdapters()', () {
      test('returns normally', () async {
        final hive = await initHive();
        expect(hive.resetAdapters, returnsNormally);
      });

      test('clears an adapter', () async {
        final hive = await initHive();
        final adapter = _TestAdapter(1);

        expect(hive.isAdapterRegistered(adapter.typeId), isFalse);
        hive.registerAdapter(adapter);
        expect(hive.isAdapterRegistered(adapter.typeId), isTrue);

        hive.resetAdapters();
        expect(hive.isAdapterRegistered(adapter.typeId), isFalse);
      });
    });
  });
}
