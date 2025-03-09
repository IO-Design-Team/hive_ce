import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import '../tests/common.dart';
import '../util/is_browser.dart';

const isolated = bool.fromEnvironment('ISOLATED', defaultValue: false);

class HiveWrapper {
  final dynamic hive;

  HiveWrapper(this.hive);

  Future<void> init(String? path) async => hive.init(path);

  Future<BoxWrapper<T>> openBox<T>(
    String name, {
    bool crashRecovery = true,
    HiveCipher? encryptionCipher,
    Uint8List? bytes,
  }) async =>
      BoxWrapper(
        await hive.openBox<T>(
          name,
          crashRecovery: crashRecovery,
          encryptionCipher: encryptionCipher,
          bytes: bytes,
        ),
      );

  Future<LazyBoxWrapper<T>> openLazyBox<T>(
    String name, {
    bool crashRecovery = true,
    HiveCipher? encryptionCipher,
  }) async =>
      LazyBoxWrapper(
        await hive.openLazyBox<T>(
          name,
          crashRecovery: crashRecovery,
          encryptionCipher: encryptionCipher,
        ),
      );

  FutureOr<void> registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) async =>
      hive.registerAdapter(adapter, internal: internal, override: override);

  FutureOr<void> resetAdapters() => hive.resetAdapters();
  FutureOr<void> ignoreTypeId<T>(int typeId) => hive.ignoreTypeId(typeId);
}

class BoxBaseWrapper<E> {
  final dynamic box;

  BoxBaseWrapper(this.box);

  String get name => box.name;
  bool get lazy => box.lazy;

  Stream<BoxEvent> watch({dynamic key}) => box.watch(key: key);
  FutureOr<bool> containsKey(dynamic key) async => box.containsKey(key);
  Future<void> put(dynamic key, E value) async => box.put(key, value);
  Future<void> putAt(int index, E value) async => box.putAt(index, value);
  Future<void> delete(dynamic key) async => box.delete(key);
  Future<void> putAll(Map<dynamic, E> entries) async => box.putAll(entries);
  Future<int> add(E value) async => box.add(value);
  Future<void> deleteAll(Iterable keys) async => box.deleteAll(keys);
  Future<void> close() async => box.close();
  FutureOr<E?> get(dynamic key, {E? defaultValue}) async =>
      box.get(key, defaultValue: defaultValue);
}

class LazyBoxWrapper<T> extends BoxBaseWrapper<T> {
  LazyBoxWrapper(super.box);
}

class BoxWrapper<T> extends BoxBaseWrapper<T> {
  BoxWrapper(super.box);
}

Future<HiveWrapper> createHive() async {
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
