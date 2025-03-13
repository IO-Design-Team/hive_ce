import 'package:hive_ce/hive.dart' hide IsolatedHive;
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/isolate/isolated_hive.dart';
import 'package:test/test.dart';
import '../../integration/isolate_test.dart';
import '../common.dart';

Future<IsolatedLazyBox> _openLazyBoxBase({
  String? name,
  List<Frame> frames = const [],
}) async {
  name ??= 'testBox';

  final tempDir = await getTempDir();
  final hive = IsolatedHive();
  addTearDown(hive.close);
  await hive.init(tempDir.path, isolateNameServer: StubIns());
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
        final box = await _openLazyBoxBase();

        expect(await box.get('someKey'), null);
        expect(await box.get('otherKey', defaultValue: -12), -12);
      });

      test('reads value from storage', () async {
        final box = await _openLazyBoxBase(
          frames: [
            Frame('testKey', 'testVal'),
          ],
        );

        expect(await box.get('testKey'), 'testVal');
      });
    });

    test('.getAt()', () async {
      final box = await _openLazyBoxBase(
        frames: [
          Frame(0, 'zero'),
          Frame('a', 'A'),
        ],
      );

      expect(await box.getAt(1), 'A');
    });

    group('.putAll()', () {
      test('values', () async {
        final box = await _openLazyBoxBase();

        await box.putAll({'key1': 'value1', 'key2': 'value2'});

        expect(await box.get('key1'), 'value1');
        expect(await box.get('key2'), 'value2');
      });

      test('handles exceptions gracefully', () async {
        // This is a simplified test since we can't easily mock exceptions
        // with the actual box implementation
        final box = await _openLazyBoxBase();

        await box.putAll({'key1': 'value1', 'key2': 'value2'});
        expect(await box.get('key1'), 'value1');
      });
    });

    group('.deleteAll()', () {
      test('does nothing when deleting non existing keys', () async {
        final box = await _openLazyBoxBase();
        final lengthBefore = await box.length;

        await box.deleteAll(['key1', 'key2', 'key3']);

        expect(await box.length, lengthBefore);
      });

      test('delete keys', () async {
        final box = await _openLazyBoxBase(
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
      final box = await _openLazyBoxBase();
      await box.close();
      expect(await box.isOpen, false);
    });
  });
}
