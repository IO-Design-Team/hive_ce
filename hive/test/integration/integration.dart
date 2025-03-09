import 'dart:io';
import 'dart:math';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import '../tests/common.dart';
import '../util/is_browser.dart';

class HiveWrapper {
  final dynamic hive;

  HiveWrapper(this.hive);

  Future<void> init(String? path) async => hive.init(path);

  Future<LazyBoxWrapper<T>> openLazyBox<T>(
    String name, {
    bool crashRecovery = true,
    HiveCipher? encryptionCipher,
  }) async =>
      LazyBoxWrapper(
        await hive.openLazyBox(
          name,
          crashRecovery: crashRecovery,
          encryptionCipher: encryptionCipher,
        ),
      );

  Future<BoxWrapper<T>> openBox<T>(
    String name, {
    bool crashRecovery = true,
    HiveCipher? encryptionCipher,
  }) async =>
      BoxWrapper(
        await hive.openBox(
          name,
          crashRecovery: crashRecovery,
          encryptionCipher: encryptionCipher,
        ),
      );
}

class BoxBaseWrapper<T> {
  final dynamic box;

  BoxBaseWrapper(this.box);

  String get name => box.name;
  bool get lazy => box.lazy;

  Future<void> close() async => box.close();
}

class LazyBoxWrapper<T> extends BoxBaseWrapper<T> {
  LazyBoxWrapper(super.box);
}

class BoxWrapper<T> extends BoxBaseWrapper<T> {
  BoxWrapper(super.box);
}

Future<HiveWrapper> createHive() async {
  final isolated = Platform.environment['ISOLATED_HIVE'] == 'true';
  final hive = HiveWrapper(isolated ? IsolatedHive() : HiveImpl());
  if (!isBrowser) {
    final dir = await getTempDir();
    await hive.init(dir.path);
  } else {
    await hive.init(null);
  }
  return hive;
}

Future<(HiveWrapper, BoxBaseWrapper<T>)> openBox<T>(
  bool lazy, {
  HiveWrapper? hive,
  List<int>? encryptionKey,
}) async {
  hive ??= await createHive();
  final id = Random.secure().nextInt(99999999);
  HiveCipher? cipher;
  if (encryptionKey != null) {
    cipher = HiveAesCipher(encryptionKey);
  }
  final BoxBaseWrapper<T> box;
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

extension HiveWrapperX on HiveWrapper {
  Future<BoxBaseWrapper<T>> reopenBox<T>(
    BoxBaseWrapper<T> box, {
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
