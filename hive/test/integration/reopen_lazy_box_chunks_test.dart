import 'package:test/test.dart';

import 'integration.dart';

/// Opening a box reads its keys in chunks, so frames that straddle a chunk
/// boundary (and frames bigger than a chunk) must survive a reopen intact.
Future _performTest(bool lazy, {required TestType type}) async {
  var (hive, box) = await openBox(lazy, type: type);
  final expected = <String, String>{};
  for (var i = 0; i < 100; i++) {
    // From a few bytes up to ~150 KB, so the box spans several 64 KB and
    // 1 MiB chunks and some frames are bigger than the default chunk.
    final value = String.fromCharCode(97 + i % 26) * ((i * 7919) % 150000 + 1);
    expected['key$i'] = value;
    await box.put('key$i', value);
  }

  box = await hive.reopenBox(box);
  expect((await box.keys).toSet(), expected.keys.toSet());
  for (final entry in expected.entries) {
    expect(await box.get(entry.key), entry.value, reason: entry.key);
  }
  await box.close();
}

void main() {
  hiveIntegrationTest((type) {
    group(
      'reopen a box whose frames cross read chunks',
      () {
        test('normal box', () => _performTest(false, type: type));

        test('lazy box', () => _performTest(true, type: type));
      },
      timeout: longTimeout,
    );
  });
}
