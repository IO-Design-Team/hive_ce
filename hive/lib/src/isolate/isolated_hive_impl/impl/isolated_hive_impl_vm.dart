import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

part 'isolated_hive_impl_vm_internal.dart';

/// Handles Hive operations in an isolate
///
/// Limitations:
/// - [IsolatedHive] does not support [HiveObject]s
/// - Most methods are async due to isolate communication
class IsolatedHiveImpl implements IsolatedHiveInterface{
  /// The name of the hive isolate
  static const isolateName = '_hive_isolate';

  /// Warning message printed when using [IsolatedHive] without an [IsolateNameServer]
  @visibleForTesting
  static final noIsolateNameServerWarning = '''
⚠️ WARNING: HIVE MULTI-ISOLATE RISK DETECTED ⚠️

Using IsolatedHive without an IsolateNameServer is unsafe. This can lead to
DATA CORRUPTION as Hive boxes are not designed for concurrent access across
isolates. Using an IsolateNameServer allows IsolatedHive to maintain a single
isolate for all Hive operations.

RECOMMENDED ACTIONS:
- Initialize IsolatedHive with IsolatedHive.initFlutter from hive_ce_flutter
- Provide your own IsolateNameServer

''';

  late final IsolateNameServer? _isolateNameServer;
  late final IsolateConnection _connection;
  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

  bool _open = true;

  IsolateEntryPoint _entryPoint = isolateEntryPoint;

  /// Must only be called once per isolate
  ///
  /// If accessing Hive in multiple isolates, an [isolateNameSever] MUST be
  /// passed to avoid box corruption
  Future<void> init(
    String? path, {
    IsolateNameServer? isolateNameServer,
  }) async {
    _isolateNameServer = isolateNameServer;

    if (_isolateNameServer == null) {
      debugPrint(noIsolateNameServerWarning);
    }

    final send = _isolateNameServer?.lookupPortByName(isolateName);
    if (send != null) {
      _connection = connectToIsolate(send);
    } else {
      _connection = await spawnIsolate(
        _entryPoint,
        debugName: isolateName,
        onExit: () {
          _isolateNameServer?.removePortNameMapping(isolateName);
          close();
        },
        onConnect: (send) =>
            _isolateNameServer?.registerPortWithName(send, isolateName),
      );
    }

    _hiveChannel = IsolateMethodChannel('hive', _connection);
    _boxChannel = IsolateMethodChannel('box', _connection);

    return _hiveChannel.invokeMethod('init', path);
  }

  /// Open a box in the isolate
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
    return IsolatedBox(_boxChannel, _connection, name, false);
  }

  /// Open a lazy box in the isolate
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
    return IsolatedLazyBox(_boxChannel, _connection, name, true);
  }

  /// Get an object to communicate with the isolated box
  Future<IsolatedBox<E>> box<E>(String name) async {
    name = name.toLowerCase();
    await _hiveChannel.invokeMethod('box', {'name': name});
    return IsolatedBox(_boxChannel, _connection, name, false);
  }

  /// Get an object to communicate with the isolated box
  Future<IsolatedLazyBox<E>> lazyBox<E>(String name) async {
    name = name.toLowerCase();
    await _hiveChannel.invokeMethod('lazyBox', {'name': name});
    return IsolatedLazyBox(_boxChannel, _connection, name, true);
  }

  /// Check if a box is open in the isolate
  Future<bool> isBoxOpen(String name) =>
      _hiveChannel.invokeMethod('isBoxOpen', name.toLowerCase());

  /// Shutdown the isolate
  Future<void> close() async {
    if (!_open) return;
    await _hiveChannel.invokeMethod('close');
    _connection.close();
    _open = false;
  }

  /// Delete a box from the disk
  Future<void> deleteBoxFromDisk(String name, {String? path}) =>
      _hiveChannel.invokeMethod(
        'deleteBoxFromDisk',
        {'name': name.toLowerCase(), 'path': path},
      );

  /// Delete all boxes from the disk
  Future<void> deleteFromDisk() => _hiveChannel.invokeMethod('deleteFromDisk');

  /// Check if a box exists in the isolate
  Future<bool> boxExists(String name, {String? path}) => _hiveChannel
      .invokeMethod('boxExists', {'name': name.toLowerCase(), 'path': path});

  /// Register an adapter in the isolate
  ///
  /// WARNING: Validation checks are not as strong as with [Hive]
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

  /// Check if an adapter is registered in the isolate
  Future<bool> isAdapterRegistered(int typeId) =>
      _hiveChannel.invokeMethod('isAdapterRegistered', typeId);

  /// Reset the adapters in the isolate
  @visibleForTesting
  Future<void> resetAdapters() => _hiveChannel.invokeMethod('resetAdapters');

  /// Ignore a type id in the isolate
  Future<void> ignoreTypeId<T>(int typeId) =>
      _hiveChannel.invokeMethod('ignoreTypeId', typeId);
}
