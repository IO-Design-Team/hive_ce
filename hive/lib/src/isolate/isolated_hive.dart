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
  late final IsolateConnection _connection;
  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

  IsolateEntryPoint _entryPoint = isolateEntryPoint;

  /// Must only be called once per isolate
  ///
  /// If accessing Hive in multiple isolates, an [isolateNameSever] MUST be
  /// passed to avoid box corruption
  Future<void> init(
    String? path, {
    // Unused
    HiveStorageBackendPreference? backendPreference,
    // TODO: Implement this
    Object? isolateNameServer,
  }) async {
    _connection = await spawnIsolate(_entryPoint);
    _hiveChannel = IsolateMethodChannel('hive', _connection);
    _boxChannel = IsolateMethodChannel('box', _connection);
    return _hiveChannel.invokeMethod('init', path);
  }

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

  IsolatedBox<E> box<E>(String name) => IsolatedBox(
        _hiveChannel,
        IsolateEventChannel('box_$name', _connection),
        name,
        false,
      );

  IsolatedLazyBox<E> lazyBox<E>(String name) => IsolatedLazyBox(
        _boxChannel,
        IsolateEventChannel('box_$name', _connection),
        name,
        true,
      );

  Future<bool> isBoxOpen(String name) =>
      _hiveChannel.invokeMethod('isBoxOpen', name);

  Future<void> close() async {
    await _hiveChannel.invokeMethod('close');
    _connection.shutdown();
  }

  Future<void> deleteBoxFromDisk(String name, {String? path}) => _hiveChannel
      .invokeMethod('deleteBoxFromDisk', {'name': name, 'path': path});

  Future<void> deleteFromDisk() => _hiveChannel.invokeMethod('deleteFromDisk');

  Future<bool> boxExists(String name, {String? path}) =>
      _hiveChannel.invokeMethod('boxExists', {'name': name, 'path': path});

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

  Future<bool> isAdapterRegistered(int typeId) =>
      _hiveChannel.invokeMethod('isAdapterRegistered', typeId);

  @visibleForTesting
  Future<void> resetAdapters() => _hiveChannel.invokeMethod('resetAdapters');

  Future<void> ignoreTypeId<T>(int typeId) =>
      _hiveChannel.invokeMethod('ignoreTypeId', typeId);
}
