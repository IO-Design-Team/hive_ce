@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../tests/backend/vm/storage_backend_vm_test.dart';
import '../tests/common.dart';
import '../tests/frames.dart';
import '../util/print_utils.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required TestType type}) async {
  final bytes = getFrameBytes(testFrames);
  final frames = testFrames;

  framesSetLengthOffset(frames, frameBytes);

  final dir = await getTempDir();
  final hive = await createHive(
    type: type,
    directory: dir,
    entryPoint: (send) => silenceOutput(() => isolateEntryPoint(send)),
  );

  for (var i = 0; i < bytes.length; i++) {
    final subBytes = bytes.sublist(0, i + 1);
    final boxFile = File(path.join(dir.path, 'testbox$i.hive'));
    await boxFile.writeAsBytes(subBytes);

    final subFrames =
        frames.takeWhile((f) => f.offset + expectNotNull(f.length) <= i + 1);
    final subKeystore = Keystore.debug(frames: subFrames);
    if (lazy) {
      final box = await hive.openLazyBox('testbox$i');
      expect(await box.keys, subKeystore.getKeys());
      await box.compact();
      await box.close();
    } else {
      final box = await hive.openBox('testbox$i');
      final map = Map.fromIterables(
        subKeystore.getKeys(),
        subKeystore.getValues(),
      );
      expect(await box.toMap(), map);
      await box.compact();
      await box.close();
    }

    expect(await boxFile.readAsBytes(), getFrameBytes(subFrames));
  }
}

void main() {
  hiveIntegrationTest((type) {
    group(
      'test recovery',
      () {
        test(
          'normal box',
          () => silenceOutput(() => _performTest(false, type: type)),
        );

        test(
          'lazy box',
          () => silenceOutput(() => _performTest(true, type: type)),
        );
      },
      timeout: longTimeout,
    );

    group('a cipher mismatch keeps the box', () {
      final keyA = HiveAesCipher(List.filled(32, 1));
      final keyB = HiveAesCipher(List.filled(32, 2));
      final mismatches = <(String, HiveCipher?, HiveCipher?)>[
        ('wrong key', keyA, keyB),
        ('no key on an encrypted box', keyA, null),
        // IsolatedHive opens this as legacy data instead, so nothing gets deleted.
        if (type == TestType.normal) ('key on a plain box', null, keyA),
      ];

      for (final (name, written, opened) in mismatches) {
        for (final lazy in [false, true]) {
          test(
            lazy ? '$name, lazy' : name,
            () => silenceOutput(() async {
              final hive = await createHive(
                type: type,
                entryPoint: (send) =>
                    silenceOutput(() => isolateEntryPoint(send)),
              );
              final boxName = generateBoxName();
              final box = await hive.openBox<String>(
                boxName,
                encryptionCipher: written,
              );
              await box.put('key', 'value');
              await box.close();

              await expectLater(
                lazy
                    ? hive.openLazyBox<String>(
                        boxName,
                        encryptionCipher: opened,
                      )
                    : hive.openBox<String>(boxName, encryptionCipher: opened),
                throwsIsolatedHiveError(),
              );

              final reopened = await hive.openBox<String>(
                boxName,
                encryptionCipher: written,
              );
              expect(await reopened.get('key'), 'value');
            }),
          );
        }
      }
    });
  });
}
