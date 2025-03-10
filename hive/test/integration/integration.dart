import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:test/test.dart';

import '../tests/common.dart';
import '../util/is_browser.dart';

class HiveWrapper {
  final dynamic hive;

  HiveWrapper(this.hive);

  FutureOr<void> init(String? path) => hive.init(path);

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

  Future<void> close() => hive.close();

  FutureOr<void> registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) =>
      hive.registerAdapter(adapter, internal: internal, override: override);

  FutureOr<void> resetAdapters() => hive.resetAdapters();
  FutureOr<void> ignoreTypeId<T>(int typeId) => hive.ignoreTypeId(typeId);
}

class BoxBaseWrapper<E> {
  final dynamic box;

  BoxBaseWrapper(this.box);

  String get name => box.name;
  String? get path => box.path;
  bool get lazy => box.lazy;
  FutureOr<Iterable> get keys => box.keys;
  Stream<BoxEvent> watch({dynamic key}) => box.watch(key: key);
  FutureOr<bool> containsKey(dynamic key) => box.containsKey(key);
  Future<void> put(dynamic key, E value) => box.put(key, value);
  Future<void> putAt(int index, E value) => box.putAt(index, value);
  Future<void> delete(dynamic key) => box.delete(key);
  Future<void> putAll(Map<dynamic, E> entries) => box.putAll(entries);
  Future<int> add(E value) => box.add(value);
  Future<void> deleteAll(Iterable keys) => box.deleteAll(keys);
  Future<void> compact() => box.compact();
  Future<void> close() => box.close();
  FutureOr<E?> get(dynamic key, {E? defaultValue}) =>
      box.get(key, defaultValue: defaultValue);
}

class LazyBoxWrapper<E> extends BoxBaseWrapper<E> {
  LazyBoxWrapper(super.box);
}

class BoxWrapper<E> extends BoxBaseWrapper<E> {
  BoxWrapper(super.box);

  FutureOr<Map<dynamic, E>> toMap() => box.toMap();
}

Future<HiveWrapper> createHive({
  required bool isolated,
  Directory? directory,
  IsolateEntryPoint? entryPoint,
}) async {
  final HiveWrapper hive;
  if (isolated) {
    final isolatedHive = IsolatedHive();
    if (entryPoint != null) {
      isolatedHive.entryPoint = entryPoint;
    }
    hive = HiveWrapper(isolatedHive);
  } else {
    hive = HiveWrapper(HiveImpl());
  }

  addTearDown(hive.close);
  if (!isBrowser) {
    final dir = directory ?? await getTempDir();
    await hive.init(dir.path);
  } else {
    await hive.init(null);
  }
  return hive;
}

Future<(HiveWrapper, BoxBaseWrapper<T>)> openBox<T>(
  bool lazy, {
  HiveWrapper? hive,
  required bool isolated,
  List<int>? encryptionKey,
}) async {
  hive ??= await createHive(isolated: isolated);
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

void hiveIntegrationTest(void Function(bool isolated) test) {
  test(false);
  group(
    'IsolatedHive',
    () => test(true),
    onPlatform: {
      'chrome': Skip('Isolates are not supported on web'),
    },
  );
}
