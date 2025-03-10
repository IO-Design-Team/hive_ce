@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../tests/backend/vm/storage_backend_vm_test.dart';
import '../tests/common.dart';
import '../tests/frames.dart';
import '../util/print_utils.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required bool isolated}) async {
  final bytes = getFrameBytes(testFrames);
  final frames = testFrames;

  framesSetLengthOffset(frames, frameBytes);

  final dir = await getTempDir();
  final hive = await createHive(
    isolated: isolated,
    directory: dir,
    entryPoint: (send) => silenceOutput(() => isolateEntryPoint(send)),
  );

  for (var i = 0; i < bytes.length; i++) {
    final subBytes = bytes.sublist(0, i + 1);
    final boxFile = File(path.join(dir.path, 'testbox$i.hive'));
    await boxFile.writeAsBytes(subBytes);

    final subFrames = frames.takeWhile((f) => f.offset + f.length! <= i + 1);
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
  hiveIntegrationTest((isolated) {
    group(
      'test recovery',
      () {
        test(
          'normal box',
          () => silenceOutput(() => _performTest(false, isolated: isolated)),
        );

        test(
          'lazy box',
          () => silenceOutput(() => _performTest(true, isolated: isolated)),
        );
      },
      timeout: longTimeout,
    );
  });
}
