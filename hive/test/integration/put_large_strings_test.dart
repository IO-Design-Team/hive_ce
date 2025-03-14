import 'package:test/test.dart';

import 'integration.dart';

Future _performTest(bool lazy, {required bool isolated}) async {
  var (hive, box) = await openBox(lazy, isolated: isolated);
  for (var i = 0; i < 5; i++) {
    final largeString = i.toString() * 1000000;
    await box.put('string$i', largeString);
  }

  box = await hive.reopenBox(box);
  for (var i = 0; i < 5; i++) {
    final largeString = await box.get('string$i');

    expect(largeString == i.toString() * 1000000, true);
  }
  await box.close();
}

void main() {
  hiveIntegrationTest((isolated) {
    group(
      'put large strings',
      () {
        test('normal box', () => _performTest(false, isolated: isolated));

        test('lazy box', () => _performTest(true, isolated: isolated));
      },
      timeout: longTimeout,
    );
  });
}
