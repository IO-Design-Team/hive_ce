@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../tests/common.dart';
import '../util/print_utils.dart';
import 'integration.dart';

Uint8List _largeValue(int seed) {
  final value = Uint8List(80 * 1024);
  for (var i = 0; i < value.length; i++) {
    value[i] = (i + seed) & 0xff;
  }
  return value;
}

Future<void> _reopenRoundTrip({required TestType type}) async {
  final dir = await getTempDir();
  final hive = await createHive(type: type, directory: dir);
  final name = generateBoxName();
  final first = _largeValue(1);
  final replaced = _largeValue(2);
  final third = _largeValue(3);

  var box = await hive.openLazyBox(name);
  await box.put('first', 'small');
  final id = await box.add(first);
  await box.put('second', replaced);
  await box.delete('second');
  await box.put('third', third);
  await box.put('fourth', 'tail');
  await box.put('third', replaced);
  await box.put('emoji 😀', third);
  await box.close();

  box = await hive.openLazyBox(name);
  expect(await box.containsKey('second'), false);
  expect(await box.get('first'), 'small');
  expect(await box.get(id), first);
  expect(await box.get('third'), replaced);
  expect(await box.get('fourth'), 'tail');
  expect(await box.get('emoji 😀'), third);
  expect((await box.keys).length, 5);

  await box.compact();
  await box.close();

  box = await hive.openLazyBox(name);
  expect(await box.get(id), first);
  expect(await box.get('third'), replaced);
  expect(await box.get('emoji 😀'), third);
  final next = await box.add(_largeValue(4));
  expect(next, greaterThan(id));
  await box.close();
}

Future<void> _recoverTruncatedFrame({required TestType type}) async {
  final dir = await getTempDir();
  final hive = await createHive(type: type, directory: dir);
  final name = generateBoxName();
  final kept = _largeValue(5);

  var box = await hive.openLazyBox(name);
  await box.put('keep', kept);
  await box.put('small', 'ok');
  await box.put('drop', _largeValue(6));
  await box.close();

  final file = File(path.join(dir.path, '${name.toLowerCase()}.hive'));
  final bytes = await file.readAsBytes();
  await file.writeAsBytes(bytes.sublist(0, bytes.length - 1000));

  box = await silenceOutput(() => hive.openLazyBox(name));
  expect(await box.containsKey('drop'), false);
  expect(await box.get('keep'), kept);
  expect(await box.get('small'), 'ok');
  await box.close();

  expect(await file.length(), lessThan(bytes.length));
}

Future<void> _encryptedLargeValue({required TestType type}) async {
  final hive = await createHive(type: type);
  final name = generateBoxName();
  final key = List<int>.filled(32, 7);
  final wrongKey = List<int>.filled(32, 8);
  final value = _largeValue(9);

  var box = await hive.openLazyBox(name, encryptionCipher: HiveAesCipher(key));
  await box.put('secret', value);
  await box.put('after', 'plain-looking');
  await box.close();

  box = await hive.openLazyBox(name, encryptionCipher: HiveAesCipher(key));
  expect(await box.get('secret'), value);
  expect(await box.get('after'), 'plain-looking');
  await box.close();

  await expectLater(
    hive.openLazyBox(name, encryptionCipher: HiveAesCipher(wrongKey)),
    throwsIsolatedHiveError(['encryption cipher']),
  );

  box = await hive.openLazyBox(name, encryptionCipher: HiveAesCipher(key));
  expect(await box.get('secret'), value);
  await box.close();
}

void main() {
  hiveIntegrationTest((type) {
    test(
      'reopens large lazy values ($type)',
      () => _reopenRoundTrip(type: type),
      timeout: longTimeout,
    );

    test(
      'recovers a truncated large frame ($type)',
      () => silenceOutput(() => _recoverTruncatedFrame(type: type)),
      timeout: longTimeout,
    );

    test(
      'checks the cipher of a large lazy box ($type)',
      () => silenceOutput(() => _encryptedLargeValue(type: type)),
      timeout: longTimeout,
    );
  });
}
