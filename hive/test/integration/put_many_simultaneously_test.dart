import 'package:test/test.dart';

import '../util/is_browser/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required bool isolated}) async {
  final amount = isBrowser ? 10 : 100;
  var (hive, box) = await openBox(lazy, isolated: isolated);

  Future putEntries() async {
    for (var i = 0; i < amount; i++) {
      await box.put('key$i', 'value$i');
    }
  }

  final futures = <Future>[];
  for (var i = 0; i < 10; i++) {
    futures.add(putEntries());
  }
  await Future.wait(futures);

  box = await hive.reopenBox(box);
  for (var i = 0; i < amount; i++) {
    expect(await box.get('key$i'), 'value$i');
  }
  await box.close();
}

void main() {
  hiveIntegrationTest((isolated) {
    group(
      'put many entries simultaneously',
      () {
        test('normal box', () => _performTest(false, isolated: isolated));

        test('lazy box', () => _performTest(true, isolated: isolated));
      },
      timeout: longTimeout,
    );
  });
}
