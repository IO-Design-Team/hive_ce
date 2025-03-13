import 'package:test/test.dart';

import '../tests/frames.dart';
import '../util/is_browser/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required bool isolated}) async {
  final repeat = isBrowser ? 20 : 1000;
  var (hive, box) = await openBox(lazy, isolated: isolated);
  final entries = <String, dynamic>{};
  for (var i = 0; i < repeat; i++) {
    for (final frame in valueTestFrames) {
      entries['${frame.key}n$i'] = frame.value;
    }
  }
  await box.putAll(entries);

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
      'put many entries in a single batch',
      () {
        test('normal box', () => _performTest(false, isolated: isolated));

        test('lazy box', () => _performTest(true, isolated: isolated));
      },
      timeout: longTimeout,
    );
  });
}
