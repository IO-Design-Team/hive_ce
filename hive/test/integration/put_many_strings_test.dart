import 'package:test/test.dart';

import '../tests/frames.dart';
import '../util/is_browser/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required bool isolated}) async {
  final hive = await createHive(isolated: isolated);
  final repeat = isBrowser ? 20 : 1000;
  var (_, box) = await openBox(lazy, isolated: isolated, hive: hive);
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
  hiveIntegrationTest((isolated) {
    group(
      'put many strings',
      () {
        test('normal box', () => _performTest(false, isolated: isolated));

        test('lazy box', () => _performTest(true, isolated: isolated));
      },
      timeout: longTimeout,
    );
  });
}
