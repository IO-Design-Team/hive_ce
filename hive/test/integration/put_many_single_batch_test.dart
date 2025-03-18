import 'package:test/test.dart';

import '../tests/frames.dart';
import '../util/is_browser/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required TestType type}) async {
  final repeat = isBrowser ? 20 : 1000;
  var (hive, box) = await openBox(lazy, type: type);
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
  hiveIntegrationTest((type) {
    group(
      'put many entries in a single batch',
      () {
        test('normal box', () => _performTest(false, type: type));

        test('lazy box', () => _performTest(true, type: type));
      },
      timeout: longTimeout,
    );
  });
}
