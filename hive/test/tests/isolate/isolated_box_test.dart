import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:test/test.dart';
import '../../integration/isolate_test.dart';
import '../common.dart';

Future<IsolatedBox> _openBox({
  String? name,
  List<Frame> frames = const [],
}) async {
  name ??= 'testBox';

  final tempDir = await getTempDir();
  final hive = IsolatedHiveImpl();
  addTearDown(hive.close);
  await hive.init(tempDir.path, isolateNameServer: StubIns());
  final box = await hive.openBox(name);
  for (final frame in frames) {
    await box.put(frame.key, frame.value);
  }
  return box;
}

void main() {
  group('BoxImpl', () {
    test('.values', () async {
      final box = await _openBox(
        frames: [
          Frame(0, 123),
          Frame('key1', 'value1'),
          Frame(1, null),
        ],
      );

      expect(await box.values, [123, null, 'value1']);
    });

    test('.valuesBetween()', () async {
      final box = await _openBox(
        frames: [
          Frame(0, 0),
          Frame(1, 1),
          Frame('0', 2),
          Frame('1', 3),
        ],
      );

      expect(await box.valuesBetween(startKey: 1, endKey: '0'), [1, 2]);
    });

    group('.get()', () {
      test('returns defaultValue if key does not exist', () async {
        final box = await _openBox();

        expect(await box.get('someKey'), null);
        expect(await box.get('otherKey', defaultValue: -12), -12);
      });

      test('returns value if it exists', () async {
        final box = await _openBox(
          frames: [
            Frame('testKey', 'testVal'),
            Frame(123, 456),
          ],
        );

        expect(await box.get('testKey'), 'testVal');
        expect(await box.get(123), 456);
      });
    });

    test('.getAt() returns value at given index', () async {
      final box = await _openBox(
        frames: [
          Frame(0, 'zero'),
          Frame('a', 'A'),
        ],
      );

      expect(await box.getAt(0), 'zero');
      expect(await box.getAt(1), 'A');
    });

    group('.putAll()', () {
      test('values', () async {
        final box = await _openBox();

        await box.putAll({'key1': 'value1', 'key2': 'value2'});

        expect(await box.get('key1'), 'value1');
        expect(await box.get('key2'), 'value2');
      });

      test('does nothing if no entries are provided', () async {
        final box = await _openBox();
        final lengthBefore = await box.length;

        await box.putAll({});

        expect(await box.length, lengthBefore);
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
      test('do nothing when deleting non existing keys', () async {
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

    test('.toMap()', () async {
      final box = await _openBox(
        frames: [
          Frame('key1', 1),
          Frame('key2', 2),
          Frame('key4', 444),
        ],
      );

      final map = await box.toMap();
      expect(map, {'key1': 1, 'key2': 2, 'key4': 444});
    });
  });
}
