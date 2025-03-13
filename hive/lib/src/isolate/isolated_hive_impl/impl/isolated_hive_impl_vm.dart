import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/isolate/isolated_box_impl/isolated_box_impl_vm.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

/// Handles Hive operations in an isolate
///
/// Limitations:
/// - [IsolatedHive] does not support [HiveObject]s
/// - Most methods are async due to isolate communication
class IsolatedHiveImpl extends HiveIsolate implements IsolatedHiveInterface {
  late final IsolateNameServer? _isolateNameServer;
  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

  bool _open = true;

  @override
  Future<void> init(
    String? path, {
    IsolateNameServer? isolateNameServer,
  }) async {
    _isolateNameServer = isolateNameServer;

    if (_isolateNameServer == null) {
      debugPrint(HiveIsolate.noIsolateNameServerWarning);
    }

    final send = _isolateNameServer?.lookupPortByName(HiveIsolate.isolateName);
    if (send != null) {
      connection = connectToIsolate(send);
    } else {
      connection = await spawnIsolate(
        entryPoint,
        debugName: HiveIsolate.isolateName,
        onExit: () {
          _isolateNameServer?.removePortNameMapping(HiveIsolate.isolateName);
          close();
        },
        onConnect: (send) => _isolateNameServer?.registerPortWithName(
          send,
          HiveIsolate.isolateName,
        ),
      );
    }

    _hiveChannel = IsolateMethodChannel('hive', connection);
    _boxChannel = IsolateMethodChannel('box', connection);

    return _hiveChannel.invokeMethod('init', path);
  }

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
  }) async {
    name = name.toLowerCase();
    await _hiveChannel.invokeMethod('openBox', {
      'name': name,
      'encryptionCipher': encryptionCipher,
      'keyComparator': keyComparator,
      'compactionStrategy': compactionStrategy,
      'crashRecovery': crashRecovery,
      'path': path,
      'bytes': bytes,
      'collection': collection,
    });
    return IsolatedBoxImpl(_boxChannel, connection, name, false);
  }

  @override
  Future<IsolatedLazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
  }) async {
    name = name.toLowerCase();
    await _hiveChannel.invokeMethod('openLazyBox', {
      'name': name,
      'encryptionCipher': encryptionCipher,
      'keyComparator': keyComparator,
      'compactionStrategy': compactionStrategy,
      'crashRecovery': crashRecovery,
      'path': path,
      'collection': collection,
    });
    return IsolatedLazyBoxImpl(_boxChannel, connection, name, true);
  }

  @override
  IsolatedBox<E> box<E>(String name) =>
      IsolatedBoxImpl(_boxChannel, connection, name.toLowerCase(), false);

  @override
  IsolatedLazyBox<E> lazyBox<E>(String name) =>
      IsolatedLazyBoxImpl(_boxChannel, connection, name.toLowerCase(), true);

  @override
  Future<bool> isBoxOpen(String name) =>
      _hiveChannel.invokeMethod('isBoxOpen', name.toLowerCase());

  @override
  Future<void> close() async {
    if (!_open) return;
    await _hiveChannel.invokeMethod('close');
    connection.close();
    _open = false;
  }

  @override
  Future<void> deleteBoxFromDisk(String name, {String? path}) =>
      _hiveChannel.invokeMethod(
        'deleteBoxFromDisk',
        {'name': name.toLowerCase(), 'path': path},
      );

  @override
  Future<void> deleteFromDisk() => _hiveChannel.invokeMethod('deleteFromDisk');

  @override
  Future<bool> boxExists(String name, {String? path}) => _hiveChannel
      .invokeMethod('boxExists', {'name': name.toLowerCase(), 'path': path});

  @override
  Future<void> registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) {
    final typeId =
        TypeRegistryImpl.calculateTypeId(adapter.typeId, internal: internal);
    final resolved = ResolvedAdapter(adapter, typeId);
    TypeRegistryImpl.validateAdapterType(resolved);
    return _hiveChannel.invokeMethod('registerAdapter', {
      // We must pass a ResolvedAdapter into the isolate to preserve type
      // information
      'adapter': resolved,
      'internal': internal,
      'override': override,
    });
  }

  @override
  Future<bool> isAdapterRegistered(int typeId) =>
      _hiveChannel.invokeMethod('isAdapterRegistered', typeId);

  @override
  @visibleForTesting
  Future<void> resetAdapters() => _hiveChannel.invokeMethod('resetAdapters');

  @override
  Future<void> ignoreTypeId<T>(int typeId) =>
      _hiveChannel.invokeMethod('ignoreTypeId', typeId);
}
