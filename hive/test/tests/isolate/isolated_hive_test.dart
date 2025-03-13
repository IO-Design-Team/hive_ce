import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:test/test.dart';

import '../../integration/isolate_test.dart';
import '../../util/is_browser/is_browser.dart';
import '../common.dart';

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
  group('IsolatedHive', () {
    Future<IsolatedHiveImpl> initHive() async {
      final hive = IsolatedHiveImpl();
      addTearDown(hive.close);

      final dir = isBrowser ? null : await getTempDir();
      await hive.init(dir?.path, isolateNameServer: StubIns());
      return hive;
    }

    test('.init()', () {
      final hive = IsolatedHiveImpl();
      expect(hive.init('MYPATH', isolateNameServer: StubIns()), completes);
    });

    group('.openBox()', () {
      group('box already open', () {
        test('throw HiveError if opened box is lazy', () async {
          final hive = await initHive();

          await hive.openLazyBox('LAZYBOX');
          await expectLater(
            () => hive.openBox('lazyBox'),
            throwsIsolatedHiveError(
              'is already open and of type LazyBox<dynamic>',
            ),
          );
        });

        test('throw HiveError if already opening box is lazy', () async {
          final hive = await initHive();

          await Future.wait([
            hive.openLazyBox('TESTBOX'),
            expectLater(
              hive.openBox('testbox'),
              throwsIsolatedHiveError(
                'is already open and of type LazyBox<dynamic>',
              ),
            ),
          ]);
        });
      });
    });

    group('.openLazyBox()', () {
      group('box already open', () {
        test('throw HiveError if opened box is not lazy', () async {
          final hive = await initHive();

          await hive.openBox('LAZYBOX');
          await expectLater(
            () => hive.openLazyBox('lazyBox'),
            throwsIsolatedHiveError('is already open and of type Box<dynamic>'),
          );
        });

        test('throw HiveError if already opening box is not lazy', () async {
          final hive = await initHive();

          await Future.wait([
            hive.openBox('LAZYBOX'),
            expectLater(
              hive.openLazyBox('lazyBox'),
              throwsIsolatedHiveError(
                'is already open and of type Box<dynamic>',
              ),
            ),
          ]);
        });
      });
    });

    group('.box()', () {
      test('throws HiveError if box type does not match', () async {
        final hive = await initHive();

        await hive.openLazyBox('LAZYBOX');
        expect(
          () => hive.box('lazyBox'),
          throwsIsolatedHiveError(
            'is already open and of type LazyBox<dynamic>',
          ),
        );
      });
    });

    group('.lazyBox()', () {
      test('throws HiveError if box type does not match', () async {
        final hive = await initHive();

        await hive.openBox('BOX');
        expect(
          () => hive.lazyBox('box'),
          throwsIsolatedHiveError('is already open and of type Box<dynamic>'),
        );
      });
    });

    test('isBoxOpen()', () async {
      final hive = await initHive();

      await hive.openBox('testBox');

      expect(await hive.isBoxOpen('testBox'), true);
      expect(await hive.isBoxOpen('nonExistingBox'), false);
    });

    test('.close()', () async {
      final hive = await initHive();

      final box1 = await hive.openBox('box1');
      final box2 = await hive.openBox('box2');
      expect(await box1.isOpen, true);
      expect(await box2.isOpen, true);

      await box1.close();
      await box2.close();

      expect(await box1.isOpen, false);
      expect(await box2.isOpen, false);
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
          expect(await hive.isBoxOpen('testBox1'), false);
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
          expect(await hive.isBoxOpen('testBox1'), false);
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
        expect(await hive.isBoxOpen('testBox1'), false);
        expect(await hive.isBoxOpen('testBox2'), false);
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
        // TODO: Figure out why deleteFromDisk never completes on web
        skip: isBrowser,
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

        expect(await hive.isAdapterRegistered(adapter.typeId), isFalse);
        await hive.registerAdapter(adapter);
        expect(await hive.isAdapterRegistered(adapter.typeId), isTrue);

        await hive.resetAdapters();
        expect(await hive.isAdapterRegistered(adapter.typeId), isFalse);
      });
    });
  });
}
