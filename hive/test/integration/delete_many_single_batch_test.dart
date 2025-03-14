import 'package:test/test.dart';

import '../util/is_browser/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required bool isolated}) async {
  final amount = isBrowser ? 500 : 20000;
  var (hive, box) = await openBox(lazy, isolated: isolated);
  final entries = <String, dynamic>{};
  for (var i = 0; i < amount; i++) {
    entries['string$i'] = 'test';
    entries['int$i'] = -i;
    entries['bool$i'] = i % 2 == 0;
    entries['null$i'] = null;
  }
  await box.putAll(entries);
  await box.put('123123', 'value');

  box = await hive.reopenBox(box);
  await box.deleteAll(entries.keys);

  box = await hive.reopenBox(box);
  for (var i = 0; i < amount; i++) {
    expect(await box.containsKey('string$i'), false);
    expect(await box.containsKey('int$i'), false);
    expect(await box.containsKey('bool$i'), false);
    expect(await box.containsKey('null$i'), false);
  }
  expect(await box.get('123123'), 'value');

  await box.close();
}

void main() {
  hiveIntegrationTest((isolated) {
    group(
      'delete many entries in a single batch',
      () {
        test('normal box', () => _performTest(false, isolated: isolated));

        test('lazy box', () => _performTest(true, isolated: isolated));
      },
      timeout: longTimeout,
    );
  });
}
