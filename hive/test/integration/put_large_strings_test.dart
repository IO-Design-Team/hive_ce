import 'package:test/test.dart';

import 'integration.dart';

Future _performTest(bool lazy, {required TestType type}) async {
  var (hive, box) = await openBox(lazy, type: type);
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
  hiveIntegrationTest((type) {
    group(
      'put large strings',
      () {
        test('normal box', () => _performTest(false, type: type));

        test('lazy box', () => _performTest(true, type: type));
      },
      timeout: longTimeout,
    );
  });
}
