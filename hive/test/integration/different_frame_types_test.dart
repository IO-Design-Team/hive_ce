import 'package:test/test.dart';

import '../tests/frames.dart';
import 'integration.dart';

Future _performTest(bool encrypted, bool lazy, {required bool isolated}) async {
  final encryptionKey = encrypted ? List.generate(32, (i) => i) : null;
  var (hive, box) =
      await openBox(lazy, isolated: isolated, encryptionKey: encryptionKey);
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
  hiveIntegrationTest((isolated) {
    group(
      'different frame types',
      () {
        group('encrypted', () {
          test(
            'normal box',
            () => _performTest(true, false, isolated: isolated),
          );

          test('lazy box', () => _performTest(true, true, isolated: isolated));
        });

        group('not encrypted', () {
          test(
            'normal box',
            () => _performTest(false, false, isolated: isolated),
          );

          test('lazy box', () => _performTest(false, true, isolated: isolated));
        });
      },
      timeout: longTimeout,
    );
  });
}
