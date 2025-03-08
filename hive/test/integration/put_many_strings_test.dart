import 'package:test/test.dart';

import '../tests/frames.dart';
import '../util/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy) async {
  final hive = await createHive();
  final repeat = isBrowser ? 20 : 1000;
  var (_, box) = await openBox(lazy, hive: hive);
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
  group(
    'put many strings',
    () {
      test('normal box', () => _performTest(false));

      test('lazy box', () => _performTest(true));
    },
    timeout: longTimeout,
  );
}
