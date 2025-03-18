import 'package:test/test.dart';

import '../tests/frames.dart';
import 'integration.dart';

Future _performTest(bool encrypted, bool lazy, {required TestType type}) async {
  final encryptionKey = encrypted ? List.generate(32, (i) => i) : null;
  var (hive, box) =
      await openBox(lazy, type: type, encryptionKey: encryptionKey);
  for (final frame in valueTestFrames) {
    if (frame.deleted) continue;
    await box.put(frame.key, frame.value);
  }

  box = await hive.reopenBox(box, encryptionKey: encryptionKey);

  for (final frame in valueTestFrames) {
    if (frame.deleted) continue;
    final f = await box.get(frame.key);
    expect(f, frame.value);
  }
  await box.close();
}

void main() {
  hiveIntegrationTest((type) {
    group(
      'different frame types',
      () {
        group('encrypted', () {
          test(
            'normal box',
            () => _performTest(true, false, type: type),
          );

          test('lazy box', () => _performTest(true, true, type: type));
        });

        group('not encrypted', () {
          test(
            'normal box',
            () => _performTest(false, false, type: type),
          );

          test('lazy box', () => _performTest(false, true, type: type));
        });
      },
      timeout: longTimeout,
    );
  });
}
