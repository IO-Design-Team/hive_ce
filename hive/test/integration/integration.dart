import 'dart:math';

import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import '../tests/common.dart';
import '../util/is_browser.dart';

Future<IsolatedHive> createHive() async {
  final hive = IsolatedHive();
  if (!isBrowser) {
    final dir = await getTempDir();
    await hive.init(dir.path);
  } else {
    await hive.init(null);
  }
  return hive;
}

Future<(IsolatedHive, IsolatedBoxBase<T>)> openBox<T>(
  bool lazy, {
  IsolatedHive? hive,
  List<int>? encryptionKey,
}) async {
  hive ??= await createHive();
  final id = Random.secure().nextInt(99999999);
  HiveCipher? cipher;
  if (encryptionKey != null) {
    cipher = HiveAesCipher(encryptionKey);
  }
  final IsolatedBoxBase<T> box;
  if (lazy) {
    box = await hive.openLazyBox<T>(
      'box$id',
      crashRecovery: false,
      encryptionCipher: cipher,
    );
  } else {
    box = await hive.openBox<T>(
      'box$id',
      crashRecovery: false,
      encryptionCipher: cipher,
    );
  }
  return (hive, box);
}

extension IsolatedHiveX on IsolatedHive {
  Future<IsolatedBoxBase<T>> reopenBox<T>(
    IsolatedBoxBase<T> box, {
    List<int>? encryptionKey,
  }) async {
    await box.close();
    HiveCipher? cipher;
    if (encryptionKey != null) {
      cipher = HiveAesCipher(encryptionKey);
    }
    if (box.lazy) {
      return openLazyBox(
        box.name,
        crashRecovery: false,
        encryptionCipher: cipher,
      );
    } else {
      return this.openBox(
        box.name,
        crashRecovery: false,
        encryptionCipher: cipher,
      );
    }
  }
}

const longTimeout = Timeout(Duration(minutes: 2));
