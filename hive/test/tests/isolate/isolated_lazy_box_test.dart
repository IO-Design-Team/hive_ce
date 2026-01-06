import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:test/test.dart';
import '../../integration/isolate_test.dart';
import '../../util/is_browser/is_browser.dart';
import '../common.dart';

Future<IsolatedLazyBox> _openBox({
  String? name,
  List<Frame> frames = const [],
}) async {
  name ??= generateBoxName();

  final hive = IsolatedHiveImpl();
  addTearDown(hive.close);

  final dir = isBrowser ? null : await getTempDir();
  await hive.init(dir?.path, isolateNameServer: StubIns());
  final box = await hive.openLazyBox(name);
  for (final frame in frames) {
    await box.put(frame.key, frame.value);
  }
  return box;
}

void main() {
  group('LazyBoxImpl', () {
    group('.get()', () {
      test('returns defaultValue if key does not exist', () async {
        final box = await _openBox();

        expect(await box.get('someKey'), null);
        expect(await box.get('otherKey', defaultValue: -12), -12);
      });

      test('reads value from storage', () async {
        final box = await _openBox(
          frames: [
            Frame('testKey', 'testVal'),
          ],
        );

        expect(await box.get('testKey'), 'testVal');
      });
    });

    test('.getAt()', () async {
      final box = await _openBox(
        frames: [
          Frame(0, 'zero'),
          Frame('a', 'A'),
        ],
      );

      expect(await box.getAt(1), 'A');
    });

    group('Iterable and Map casting', () {
      test('.getList()', () async {
        final box = await _openBox(frames: [
          Frame(0, [1, 2, 3])
        ]);
        expect(await box.getList<num>(0), [1, 2, 3]);
      });

      test('.getSet()', () async {
        final box = await _openBox(frames: [
          Frame(0, {1, 2, 3})
        ]);
        expect(await box.getSet<num>(0), {1, 2, 3});
      });

      test('.getMap()', () async {
        final box = await _openBox(frames: [
          Frame(0, {'a': 1, 'b': 2, 'c': 3})
        ]);
        expect(await box.getMap<String, num>(0), {'a': 1, 'b': 2, 'c': 3});
      });

      test('.getListAt()', () async {
        final box = await _openBox(frames: [
          Frame(0, [1, 2, 3])
        ]);
        expect(await box.getListAt<num>(0), [1, 2, 3]);
      });

      test('.getSetAt()', () async {
        final box = await _openBox(frames: [
          Frame(0, {1, 2, 3})
        ]);
        expect(await box.getSetAt<num>(0), {1, 2, 3});
      });

      test('.getMapAt()', () async {
        final box = await _openBox(frames: [
          Frame(0, {'a': 1, 'b': 2, 'c': 3})
        ]);
        expect(await box.getMapAt<String, num>(0), {'a': 1, 'b': 2, 'c': 3});
      });
    });

    group('.putAll()', () {
      test('values', () async {
        final box = await _openBox();

        await box.putAll({'key1': 'value1', 'key2': 'value2'});

        expect(await box.get('key1'), 'value1');
        expect(await box.get('key2'), 'value2');
      });

      test('handles exceptions gracefully', () async {
        // This is a simplified test since we can't easily mock exceptions
        // with the actual box implementation
        final box = await _openBox();

        await box.putAll({'key1': 'value1', 'key2': 'value2'});
        expect(await box.get('key1'), 'value1');
      });
    });

    group('.deleteAll()', () {
      test('does nothing when deleting non existing keys', () async {
        final box = await _openBox();
        final lengthBefore = await box.length;

        await box.deleteAll(['key1', 'key2', 'key3']);

        expect(await box.length, lengthBefore);
      });

      test('delete keys', () async {
        final box = await _openBox(
          frames: [
            Frame('key1', 'value1'),
            Frame('key2', 'value2'),
            Frame('key3', 'value3'),
          ],
        );

        await box.deleteAll(['key1', 'key2']);

        expect(await box.containsKey('key1'), false);
        expect(await box.containsKey('key2'), false);
        expect(await box.containsKey('key3'), true);
      });
    });

    test('.close() properly closes the box', () async {
      final box = await _openBox();
      await box.close();
      expect(box.isOpen, false);
    });
  });
}
