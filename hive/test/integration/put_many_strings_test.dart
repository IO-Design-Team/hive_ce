import 'package:test/test.dart';

import '../tests/frames.dart';
import '../util/is_browser/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required TestType type}) async {
  final hive = await createHive(type: type);
  final repeat = isBrowser ? 20 : 1000;
  var (_, box) = await openBox(lazy, type: type, hive: hive);
  for (var i = 0; i < repeat; i++) {
    for (final frame in valueTestFrames) {
      await box.put('${frame.key}n$i', frame.value);
    }
  }

  box = await hive.reopenBox(box);
  for (var i = 0; i < repeat; i++) {
    for (final frame in valueTestFrames) {
      expect(await box.get('${frame.key}n$i'), frame.value);
    }
  }
  await box.close();
}

void main() {
  hiveIntegrationTest((type) {
    group(
      'put many strings',
      () {
        test('normal box', () => _performTest(false, type: type));

        test('lazy box', () => _performTest(true, type: type));
      },
      timeout: longTimeout,
    );
  });
}
