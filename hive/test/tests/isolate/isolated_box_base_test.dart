import 'package:hive_ce/hive.dart' hide IsolatedHive;
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/isolate/isolated_hive.dart';
import 'package:test/test.dart';
import '../../integration/isolate_test.dart';
import '../common.dart';

Future<IsolatedBoxBase> _openBoxBase({
  String? name,
  List<Frame> frames = const [],
}) async {
  name ??= 'testBox';

  final tempDir = await getTempDir();
  final hive = IsolatedHive();
  addTearDown(hive.close);
  await hive.init(tempDir.path, isolateNameServer: StubIns());
  final box = await hive.openBox(name);
  for (final frame in frames) {
    await box.put(frame.key, frame.value);
  }
  return box;
}

void main() {
  group('BoxBase', () {
    test('.name', () async {
      final box = await _openBoxBase(name: 'testName');
      expect(box.name, 'testname');
    });

    test('.path', () async {
      final box = await _openBoxBase();
      expect(await box.path, isNotEmpty);
    });

    group('.keys', () {
      test('returns keys from keystore', () async {
        final box = await _openBoxBase(
          frames: [
            Frame.lazy('key1'),
            Frame.lazy('key4'),
            Frame.lazy('key2'),
          ],
        );
        expect(await box.keys, ['key1', 'key2', 'key4']);
      });

      test('throws if box is closed', () async {
        final box = await _openBoxBase();
        await box.close();
        expect(box.keys, throwsIsolatedHiveError('closed'));
      });
    });

    group('.length / .isEmpty / .isNotEmpty', () {
      test('empty box', () async {
        final box = await _openBoxBase();
        expect(await box.length, 0);
        expect(await box.isEmpty, true);
        expect(await box.isNotEmpty, false);
      });

      test('non empty box', () async {
        final box = await _openBoxBase(
          frames: [
            Frame.lazy('key1'),
            Frame.lazy('key2'),
          ],
        );
        expect(await box.length, 2);
        expect(await box.isEmpty, false);
        expect(await box.isNotEmpty, true);
      });

      test('throws if box is closed', () async {
        final box = await _openBoxBase();
        await box.close();
        expect(box.length, throwsIsolatedHiveError('closed'));
        expect(box.isEmpty, throwsIsolatedHiveError('closed'));
        expect(box.isNotEmpty, throwsIsolatedHiveError('closed'));
      });
    });

    group('.watch()', () {
      test('throws if box is closed', () async {
        final box = await _openBoxBase();
        await box.close();
        expect(box.watch().drain(), throwsIsolatedHiveError('closed'));
      });
    });

    group('.keyAt()', () {
      test('returns key at index', () async {
        final box = await _openBoxBase(
          frames: [
            Frame.lazy(0),
            Frame.lazy('test'),
          ],
        );
        expect(await box.keyAt(1), 'test');
      });

      test('throws if box is closed', () async {
        final box = await _openBoxBase();
        await box.close();
        expect(box.keyAt(0), throwsIsolatedHiveError('closed'));
      });
    });

    group('.containsKey()', () {
      test('returns true if key exists', () async {
        final box = await _openBoxBase(
          frames: [
            Frame.lazy('existingKey'),
          ],
        );
        expect(await box.containsKey('existingKey'), true);
      });

      test('returns false if key does not exist', () async {
        final box = await _openBoxBase(
          frames: [
            Frame.lazy('existingKey'),
          ],
        );
        expect(await box.containsKey('nonExistingKey'), false);
      });

      test('throws if box is closed', () async {
        final box = await _openBoxBase();
        await box.close();
        expect(box.containsKey(0), throwsIsolatedHiveError('closed'));
      });
    });

    test('.add()', () async {
      final box = await _openBoxBase();
      expect(await box.add(123), 0);
      expect(await box.get(0), 123);
    });

    test('.addAll()', () async {
      final box = await _openBoxBase();

      expect(await box.addAll([1, 2, 3]), [0, 1, 2]);
      expect(await box.get(0), 1);
      expect(await box.get(1), 2);
      expect(await box.get(2), 3);
    });

    test('.putAt()', () async {
      final box = await _openBoxBase(
        frames: [
          Frame(0, 'a'),
          Frame(1, 'b'),
        ],
      );

      await box.putAt(1, 'test');
      expect(await box.get(1), 'test');
    });

    test('.deleteAt()', () async {
      final box = await _openBoxBase(
        frames: [
          Frame.lazy('a'),
          Frame.lazy('b'),
        ],
      );

      await box.deleteAt(1);
      expect(await box.get(1), null);
    });

    test('.clear()', () async {
      final box = await _openBoxBase(
        frames: [
          Frame.lazy('a'),
          Frame.lazy('b'),
        ],
      );

      expect(await box.clear(), 2);
      expect(await box.get(0), null);
    });

    test('.compact()', () async {
      final box = await _openBoxBase();
      expect(box.compact(), completes);
    });

    test('.close()', () async {
      final box = await _openBoxBase(name: 'myBox');
      await box.close();
      expect(await box.isOpen, false);
    });

    group('.deleteFromDisk()', () {
      test('closes and deletes box', () async {
        final box = await _openBoxBase(name: 'myBox');
        await box.deleteFromDisk();
        expect(await box.isOpen, false);
      });
    });
  });
}
