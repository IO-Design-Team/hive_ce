import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

part 'isolated_hive_internal.dart';

/// Handles Hive operations in an isolate
///
/// Limitations:
/// - [IsolatedHive] does not support [HiveObject]s
/// - Most methods are async due to isolate communication
class IsolatedHive {
  static const _isolateName = '_hive_isolate';

  final IsolateNameServer? _isolateNameServer;

  late final IsolateConnection _connection;
  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

  IsolateEntryPoint _entryPoint = isolateEntryPoint;

  /// Constructor
  IsolatedHive({
    IsolateNameServer? isolateNameServer,
  }) : _isolateNameServer = isolateNameServer;

  /// Must only be called once per isolate
  ///
  /// If accessing Hive in multiple isolates, an [isolateNameSever] MUST be
  /// passed to avoid box corruption
  Future<void> init(String? path) async {
    final send = _isolateNameServer?.lookupPortByName(_isolateName);
    if (send != null) {
      _connection = connectToIsolate(send);
    } else {
      _connection = await spawnIsolate(
        _entryPoint,
        onConnect: (send) =>
            _isolateNameServer?.registerPortWithName(send, _isolateName),
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
    return IsolatedBox(
      _boxChannel,
      IsolateEventChannel('box_$name', _connection),
      name,
      false,
    );
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
    await _hiveChannel.invokeMethod('openLazyBox', {
      'name': name,
      'encryptionCipher': encryptionCipher,
      'keyComparator': keyComparator,
      'compactionStrategy': compactionStrategy,
      'crashRecovery': crashRecovery,
      'path': path,
      'collection': collection,
    });
    return IsolatedLazyBox(
      _boxChannel,
      IsolateEventChannel('box_$name', _connection),
      name,
      true,
    );
  }

  /// Get an object to communicate with the isolated box
  IsolatedBox<E> box<E>(String name) => IsolatedBox(
        _boxChannel,
        IsolateEventChannel('box_$name', _connection),
        name,
        false,
      );

  /// Get an object to communicate with the isolated box
  IsolatedLazyBox<E> lazyBox<E>(String name) => IsolatedLazyBox(
        _boxChannel,
        IsolateEventChannel('box_$name', _connection),
        name,
        true,
      );

  /// Check if a box is open in the isolate
  Future<bool> isBoxOpen(String name) =>
      _hiveChannel.invokeMethod('isBoxOpen', name);

  /// Shutdown the isolate
  Future<void> close() async {
    await _hiveChannel.invokeMethod('close');
    _connection.shutdown();
  }

  /// Delete a box from the disk
  Future<void> deleteBoxFromDisk(String name, {String? path}) => _hiveChannel
      .invokeMethod('deleteBoxFromDisk', {'name': name, 'path': path});

  /// Delete all boxes from the disk
  Future<void> deleteFromDisk() => _hiveChannel.invokeMethod('deleteFromDisk');

  /// Check if a box exists in the isolate
  Future<bool> boxExists(String name, {String? path}) =>
      _hiveChannel.invokeMethod('boxExists', {'name': name, 'path': path});

  /// Register an adapter in the isolate
  Future<void> registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) =>
      _hiveChannel.invokeMethod('registerAdapter', {
        'adapter': adapter,
        'internal': internal,
        'override': override,
      });

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
