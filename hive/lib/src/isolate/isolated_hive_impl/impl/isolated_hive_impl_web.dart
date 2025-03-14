import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/box/default_compaction_strategy.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/isolate/isolated_box_impl/isolated_box_impl_web.dart';

/// Web implementation of [IsolatedHiveInterface]
///
/// All operations are delegated to [Hive] since web does not support isolates
class IsolatedHiveImpl implements IsolatedHiveInterface {
  @override
  Future<void> init(
    String? path, {
    IsolateNameServer? isolateNameServer,
  }) async =>
      Hive.init(path);

  @override
  Future<IsolatedBox<E>> openBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    Uint8List? bytes,
    String? collection,
  }) async =>
      IsolatedBoxImpl(
        await Hive.openBox(
          name,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator ?? defaultKeyComparator,
          compactionStrategy: compactionStrategy ?? defaultCompactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
          bytes: bytes,
          collection: collection,
        ),
      );

  @override
  Future<IsolatedLazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) async =>
      IsolatedLazyBoxImpl(
        await Hive.openLazyBox(
          name,
          encryptionCipher: encryptionCipher,
          keyComparator: keyComparator ?? defaultKeyComparator,
          compactionStrategy: compactionStrategy ?? defaultCompactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
        ),
      );

  @override
  IsolatedBox<E> box<E>(String name) => IsolatedBoxImpl(Hive.box(name));

  @override
  IsolatedLazyBox<E> lazyBox<E>(String name) =>
      IsolatedLazyBoxImpl(Hive.lazyBox(name));

  @override
  Future<bool> isBoxOpen(String name) async => Hive.isBoxOpen(name);

  @override
  Future<void> close() => Hive.close();

  @override
  Future<void> deleteBoxFromDisk(String name, {String? path}) =>
      Hive.deleteBoxFromDisk(name, path: path);

  @override
  Future<void> deleteFromDisk() => Hive.deleteFromDisk();

  @override
  Future<bool> boxExists(String name, {String? path}) =>
      Hive.boxExists(name, path: path);

  @override
  Future<void> registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) async =>
      Hive.registerAdapter(adapter, internal: internal, override: override);

  @override
  Future<bool> isAdapterRegistered(int typeId) async =>
      Hive.isAdapterRegistered(typeId);

  @override
  Future<void> resetAdapters() async {
    // This is an override
    // ignore: invalid_use_of_visible_for_testing_member
    Hive.resetAdapters();
  }

  @override
  Future<void> ignoreTypeId<T>(int typeId) async =>
      Hive.ignoreTypeId<T>(typeId);
}
