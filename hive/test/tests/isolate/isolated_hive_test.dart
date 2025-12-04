// This is a test
// ignore_for_file: rexios_lints/prefer_async_await
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:test/test.dart';

import '../../integration/isolate_test.dart';
import '../../util/is_browser/is_browser.dart';
import '../common.dart';

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
  group('IsolatedHive', () {
    Future<IsolatedHiveImpl> initHive() async {
      final hive = IsolatedHiveImpl();
      addTearDown(hive.close);

      final dir = isBrowser ? null : await getTempDir();
      await hive.init(dir?.path, isolateNameServer: StubIns());
      return hive;
    }

    test('.init()', () async {
      final hive = IsolatedHiveImpl();
      await expectLater(
        hive.init('MYPATH', isolateNameServer: StubIns()),
        completes,
      );

      // Multiple init calls should work
      expect(hive.init('MYPATH', isolateNameServer: StubIns()), completes);
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
            throwsHiveError(
              ['is already open and of type', 'LazyBox<dynamic>'],
            ),
          );

          await hive.close();
        });

        test('throw HiveError if already opening box is lazy', () async {
          final hive = await initHive();

          await Future.wait([
            hive.openLazyBox('TESTBOX'),
            expectLater(
              hive.openBox('testbox'),
              throwsHiveError(
                ['is already open and of type', 'LazyBox<dynamic>'],
              ),
            ),
          ]);
        });

        test('same box returned if it is already opening', () async {
          final hive = await initHive();

          IsolatedBox? box1;
          IsolatedBox? box2;
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
          IsolatedLazyBox? box1;
          IsolatedLazyBox? box2;

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
            throwsHiveError(
              ['is already open and of type', 'Box<dynamic>'],
            ),
          );

          await hive.close();
        });

        test('throw HiveError if already opening box is not lazy', () async {
          final hive = await initHive();

          await Future.wait([
            hive.openBox('LAZYBOX'),
            expectLater(
              hive.openLazyBox('lazyBox'),
              throwsHiveError(
                ['is already open and of type', 'Box<dynamic>'],
              ),
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
          throwsHiveError(['is already open and of type', 'Box<int>']),
        );

        await hive.openBox('DYNAMICBOX');
        expect(
          () => hive.box<int>('dynamicBox'),
          throwsHiveError(['is already open and of type', 'Box<dynamic>']),
        );

        await hive.openLazyBox('LAZYBOX');
        expect(
          () => hive.box('lazyBox'),
          throwsHiveError(
            ['is already open and of type', 'LazyBox<dynamic>'],
          ),
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
          throwsHiveError(['is already open and of type', 'LazyBox<int>']),
        );

        await hive.openLazyBox('DYNAMICBOX');
        expect(
          () => hive.lazyBox<int>('dynamicBox'),
          throwsHiveError(
            ['is already open and of type', 'LazyBox<dynamic>'],
          ),
        );

        await hive.openBox('BOX');
        expect(
          () => hive.lazyBox('box'),
          throwsHiveError(['is already open and of type', 'Box<dynamic>']),
        );

        await hive.close();
      });
    });

    test('isBoxOpen()', () async {
      final hive = await initHive();

      await hive.openBox('testBox');

      expect(hive.isBoxOpen('testBox'), true);
      expect(hive.isBoxOpen('nonExistingBox'), false);
    });

    test('.close()', () async {
      final hive = await initHive();

      final box1 = await hive.openBox('box1');
      final box2 = await hive.openBox('box2');
      expect(box1.isOpen, true);
      expect(box2.isOpen, true);

      await box1.close();
      await box2.close();

      expect(box1.isOpen, false);
      expect(box2.isOpen, false);
    });

    group(
      '.deleteBoxFromDisk()',
      () {
        test('deletes open box', () async {
          final hive = await initHive();

          final box1 = await hive.openBox('testBox1');
          await box1.put('key', 'value');
          final box1File = File((await box1.path)!);

          await hive.deleteBoxFromDisk('testBox1');
          expect(await box1File.exists(), false);
          expect(hive.isBoxOpen('testBox1'), false);
        });

        test('deletes closed box', () async {
          final hive = await initHive();

          final box1 = await hive.openBox('testBox1');
          await box1.put('key', 'value');
          final path = (await box1.path)!;
          await box1.close();
          final box1File = File(path);

          await hive.deleteBoxFromDisk('testBox1');
          expect(await box1File.exists(), false);
          expect(hive.isBoxOpen('testBox1'), false);
        });

        test('does nothing if files do not exist', () async {
          final hive = await initHive();
          await hive.deleteBoxFromDisk('testBox1');
        });
      },
      skip: isBrowser,
    );

    test(
      '.deleteFromDisk()',
      () async {
        final hive = await initHive();

        final box1 = await hive.openBox('testBox1');
        await box1.put('key', 'value');
        final box1File = File((await box1.path)!);

        final box2 = await hive.openBox('testBox2');
        await box2.put('key', 'value');
        final box2File = File((await box2.path)!);

        await hive.deleteFromDisk();
        expect(await box1File.exists(), false);
        expect(await box2File.exists(), false);
        expect(hive.isBoxOpen('testBox1'), false);
        expect(hive.isBoxOpen('testBox2'), false);
      },
      skip: isBrowser,
    );

    group('.boxExists()', () {
      test('returns true if a box was created', () async {
        final hive = await initHive();
        final boxName = generateBoxName();
        await hive.openBox(boxName);
        expect(await hive.boxExists(boxName), true);
      });

      test('returns false if no box was created', () async {
        final hive = await initHive();
        final boxName = generateBoxName();
        expect(await hive.boxExists(boxName), false);
      });

      test(
        'returns false if box was created and then deleted',
        () async {
          final hive = await initHive();
          final boxName = generateBoxName();
          await hive.openBox(boxName);
          await hive.deleteBoxFromDisk(boxName);
          expect(await hive.boxExists(boxName), false);
        },
      );
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
