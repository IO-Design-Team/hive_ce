import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/box/default_compaction_strategy.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

class IsolatedHive {
  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

  late final IsolateEventChannel Function(String name) _createEventChannel;

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
    final (send, receive, shutdown) = await spawnIsolate(_isolateEntryPoint);
    _hiveChannel = IsolateMethodChannel('hive', send, receive);
    _boxChannel = IsolateMethodChannel('box', send, receive);
    _createEventChannel = (name) => IsolateEventChannel(name, send, receive);
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
      _createEventChannel('box_$name'),
      name,
      false,
    );
  }

  Future<IsolatedBox<E>> openLazyBox<E>(
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
    return IsolatedBox(
      _boxChannel,
      _createEventChannel('box_$name'),
      name,
      true,
    );
  }

  IsolatedBox<E> box<E>(String name) =>
      IsolatedBox(_hiveChannel, _createEventChannel('box_$name'), name, false);

  IsolatedBox<E> lazyBox<E>(String name) =>
      IsolatedBox(_boxChannel, _createEventChannel('box_$name'), name, true);

  Future<bool> isBoxOpen(String name) =>
      _hiveChannel.invokeMethod('isBoxOpen', name);

  Future<void> close() => _hiveChannel.invokeMethod('close');

  Future<void> deleteBoxFromDisk(String name, {String? path}) => _hiveChannel
      .invokeMethod('deleteBoxFromDisk', {'name': name, 'path': path});

  Future<void> deleteFromDisk() => _hiveChannel.invokeMethod('deleteFromDisk');

  Future<bool> boxExists(String name, {String? path}) =>
      _hiveChannel.invokeMethod('boxExists', {'name': name, 'path': path});

  void registerAdapter<T>(
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

void _isolateEntryPoint(SendPort send) {
  final receive = setupIsolate(send);
  final hiveChannel = IsolateMethodChannel('hive', send, receive);
  final boxChannel = IsolateMethodChannel('box', send, receive);

  hiveChannel.setMethodCallHandler(_handleMethodCall);
  boxChannel.setMethodCallHandler(_handleBoxMethodCall);
}

void _handleMethodCall(IsolateMethodCall call, IsolateResult result) async {
  switch (call.method) {
    case 'init':
      Hive.init(call.arguments);
      result(null);
    case 'openBox':
      await Hive.openBox(
        call.arguments['name'],
        encryptionCipher: call.arguments['encryptionCipher'],
        keyComparator: call.arguments['keyComparator'] ?? defaultKeyComparator,
        compactionStrategy:
            call.arguments['compactionStrategy'] ?? defaultCompactionStrategy,
        crashRecovery: call.arguments['crashRecovery'],
        path: call.arguments['path'],
        bytes: call.arguments['bytes'],
        collection: call.arguments['collection'],
      );
      result(null);
    case 'openLazyBox':
      await Hive.openLazyBox(
        call.arguments['name'],
        encryptionCipher: call.arguments['encryptionCipher'],
        keyComparator: call.arguments['keyComparator'] ?? defaultKeyComparator,
        compactionStrategy:
            call.arguments['compactionStrategy'] ?? defaultCompactionStrategy,
        crashRecovery: call.arguments['crashRecovery'],
        path: call.arguments['path'],
        collection: call.arguments['collection'],
      );
      result(null);
    case 'isBoxOpen':
      result(Hive.isBoxOpen(call.arguments));
    case 'close':
      await Hive.close();
      result(null);
    case 'deleteBoxFromDisk':
      await Hive.deleteBoxFromDisk(
        call.arguments['name'],
        path: call.arguments['path'],
      );
      result(null);
    case 'deleteFromDisk':
      await Hive.deleteFromDisk();
      result(null);
    case 'boxExists':
      result(
        Hive.boxExists(call.arguments['name'], path: call.arguments['path']),
      );
      result(null);
    case 'registerAdapter':
      Hive.registerAdapter(
        call.arguments['adapter'],
        internal: call.arguments['internal'],
        override: call.arguments['override'],
      );
      result(null);
    case 'isAdapterRegistered':
      result(Hive.isAdapterRegistered(call.arguments));
    case 'resetAdapters':
      // This is a proxy
      // ignore: invalid_use_of_visible_for_testing_member
      Hive.resetAdapters();
      result(null);
    case 'ignoreTypeId':
      Hive.ignoreTypeId(call.arguments);
      result(null);
    default:
      throw UnimplementedError();
  }
}

void _handleBoxMethodCall(IsolateMethodCall call, IsolateResult result) async {
  switch (call.method) {
    case 'put':
      await Hive.box(call.arguments['name'])
          .put(call.arguments['key'], call.arguments['value']);
      result(null);
    default:
      throw UnimplementedError();
  }
}
