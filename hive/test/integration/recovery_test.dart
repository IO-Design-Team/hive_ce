@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:hive_ce/src/box/keystore.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../tests/backend/vm/storage_backend_vm_test.dart';
import '../tests/common.dart';
import '../tests/frames.dart';
import 'integration.dart';

Future _performTest(bool lazy, {required bool isolated}) async {
  final bytes = getFrameBytes(testFrames);
  final frames = testFrames;

  framesSetLengthOffset(frames, frameBytes);

  final dir = await getTempDir();
  final hive = await createHive(isolated: isolated, directory: dir);

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

Future _performTestWithoutOutput(bool lazy, {required bool isolated}) {
  return runZoned(
    () => _performTest(lazy, isolated: isolated),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, message) {},
    ),
  );
}

void main() {
  hiveIntegrationTest((isolated) {
    group(
      'test recovery',
      () {
        test(
          'normal box',
          () => _performTestWithoutOutput(false, isolated: isolated),
        );

        test(
          'lazy box',
          () => _performTestWithoutOutput(true, isolated: isolated),
        );
      },
      timeout: longTimeout,
    );
  });
}
