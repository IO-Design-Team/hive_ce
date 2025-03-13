import 'dart:async';

import 'package:test/test.dart';

import '../util/is_browser/is_browser.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required bool isolated}) async {
  final amount = isBrowser ? 5 : 100;
  var (hive, box) = await openBox(lazy, isolated: isolated);

  for (var i = 0; i < amount; i++) {
    for (var n = 0; n < 100; n++) {
      final completer = Completer();
      scheduleMicrotask(() async {
        await box.put('string$i', 'test$n');
        await box.put('int$i', n);
        await box.put('bool$i', n % 2 == 0);
        await box.put('null$i', null);

        expect(await box.get('string$i'), 'test$n');
        expect(await box.get('int$i'), n);
        expect(await box.get('bool$i'), n % 2 == 0);
        expect(await box.get('null$i', defaultValue: 0), null);

        completer.complete();
      });
      await completer.future;
    }
  }

  box = await hive.reopenBox(box);
  for (var i = 0; i < amount; i++) {
    expect(await box.get('string$i'), 'test99');
    expect(await box.get('int$i'), 99);
    expect(await box.get('bool$i'), false);
    expect(await box.get('null$i', defaultValue: 0), null);
  }
  await box.close();
}

void main() {
  hiveIntegrationTest((isolated) {
    group(
      'put many entries with the same key',
      () {
        test('normal box', () => _performTest(false, isolated: isolated));

        test('lazy box', () => _performTest(true, isolated: isolated));
      },
      timeout: longTimeout,
    );
  });
}
