import 'package:test/test.dart';

import 'integration.dart';

Future<void> _performTest(bool lazy, {required TestType type}) async {
  var (hive, box) = await openBox<String>(lazy, type: type);

  // Insert enough entries to span multiple B+ tree leaves (> 64).
  const total = 200;
  final expected = <int, String>{};
  for (var i = 0; i < total; i++) {
    final val = 'initial_$i';
    expected[i] = val;
    await box.put(i, val);
  }

  // Overwrite a quarter and delete half so offsets shift drastically on compact.
  for (var i = 0; i < total; i += 4) {
    final val = 'updated_${i}_extra_payload';
    expected[i] = val;
    await box.put(i, val);
  }
  for (var i = 1; i < total; i += 2) {
    expected.remove(i);
    await box.delete(i);
  }

  // Compact while open and verify packed lazy offsets are resynced immediately.
  await box.compact();

  final remainingKeys = expected.keys.toList()..sort();
  expect(await box.length, remainingKeys.length);
  for (var i = 0; i < remainingKeys.length; i++) {
    final key = remainingKeys[i];
    expect(await box.keyAt(i), key);
    expect(await box.get(key), expected[key]);
    expect(await box.getAt(i), expected[key]);
  }
  for (var i = 1; i < total; i += 2) {
    expect(await box.containsKey(i), false);
    expect(await box.get(i), null);
  }

  // Add new entries after compaction and verify across reopen.
  for (var i = total; i < total + 20; i++) {
    final val = 'after_compact_$i';
    expected[i] = val;
    await box.put(i, val);
  }

  box = await hive.reopenBox(box);
  final finalKeys = expected.keys.toList()..sort();
  expect(await box.length, finalKeys.length);
  for (var i = 0; i < finalKeys.length; i++) {
    final key = finalKeys[i];
    expect(await box.keyAt(i), key);
    expect(await box.get(key), expected[key]);
    expect(await box.getAt(i), expected[key]);
  }

  await box.close();
}

void main() {
  hiveIntegrationTest((type) {
    group(
      'compaction preserves values and packed lazy offsets',
      () {
        test('normal box', () => _performTest(false, type: type));

        test('lazy box', () => _performTest(true, type: type));
      },
      timeout: longTimeout,
    );
  });
}
