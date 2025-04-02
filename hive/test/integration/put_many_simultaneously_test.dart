import 'package:test/test.dart';

import '../util/is_browser/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required TestType type}) async {
  final amount = isBrowser ? 10 : 100;
  var (hive, box) = await openBox(lazy, type: type);

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
  hiveIntegrationTest((type) {
    group(
      'put many entries simultaneously',
      () {
        test('normal box', () => _performTest(false, type: type));

        test('lazy box', () => _performTest(true, type: type));
      },
      timeout: longTimeout,
    );
  });
}
