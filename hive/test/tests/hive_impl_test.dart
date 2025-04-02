// This is a test
// ignore_for_file: prefer_async_await
@TestOn('vm')
library;

import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/adapters/date_time_adapter.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import 'common.dart';

class _TestAdapter extends TypeAdapter<int> {
  _TestAdapter([this.typeId = 0]);

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

      expect(
        hive.findAdapterForValue(DateTime.timestamp())!.adapter,
        isA<DateTimeWithTimezoneAdapter>(),
      );
      expect(hive.findAdapterForTypeId(16)!.adapter, isA<DateTimeAdapter>());
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
        final box1File = File(box1.path!);

        await hive.deleteBoxFromDisk('testBox1');
        expect(await box1File.exists(), false);
        expect(hive.isBoxOpen('testBox1'), false);

        await hive.close();
      });

      test('deletes closed box', () async {
        final hive = await initHive();

        final box1 = await hive.openBox('testBox1');
        await box1.put('key', 'value');
        final path = box1.path!;
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
      final box1File = File(box1.path!);

      final box2 = await hive.openBox('testBox2');
      await box2.put('key', 'value');
      final box2File = File(box1.path!);

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
