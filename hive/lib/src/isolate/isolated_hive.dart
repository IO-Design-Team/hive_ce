import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/box/default_compaction_strategy.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

/// Handles Hive operations in an isolate
///
/// Limitations:
/// - [IsolatedHive] does not support [HiveObject]s
/// - Most methods are async due to isolate communication
class IsolatedHive {
  late final IsolateConnection _connection;
  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

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
    _connection = await spawnIsolate(_isolateEntryPoint);
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

void _isolateEntryPoint(SendPort send) {
  final connection = setupIsolate(send);
  final hiveChannel = IsolateMethodChannel('hive', connection);
  final boxChannel = IsolateMethodChannel('box', connection);

  hiveChannel.setMethodCallHandler(_handleMethodCall);
  boxChannel.setMethodCallHandler(_handleBoxMethodCall);
}

Future<dynamic> _handleMethodCall(IsolateMethodCall call) async {
  switch (call.method) {
    case 'init':
      Hive.init(call.arguments);
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
    case 'isBoxOpen':
      return Hive.isBoxOpen(call.arguments);
    case 'close':
      await Hive.close();
    case 'deleteBoxFromDisk':
      await Hive.deleteBoxFromDisk(
        call.arguments['name'],
        path: call.arguments['path'],
      );
    case 'deleteFromDisk':
      await Hive.deleteFromDisk();
    case 'boxExists':
      return Hive.boxExists(
        call.arguments['name'],
        path: call.arguments['path'],
      );
    case 'registerAdapter':
      Hive.registerAdapter(
        call.arguments['adapter'],
        internal: call.arguments['internal'],
        override: call.arguments['override'],
      );
    case 'isAdapterRegistered':
      return Hive.isAdapterRegistered(call.arguments);
    case 'resetAdapters':
      // This is a proxy
      // ignore: invalid_use_of_visible_for_testing_member
      Hive.resetAdapters();
    case 'ignoreTypeId':
      Hive.ignoreTypeId(call.arguments);
    default:
      throw UnimplementedError();
  }
}

Future<dynamic> _handleBoxMethodCall(IsolateMethodCall call) async {
  final name = call.arguments['name'];
  final lazy = call.arguments['lazy'];
  final box = lazy ? Hive.lazyBox(name) : Hive.box(name);

  switch (call.method) {
    case 'path':
      return box.path;
    case 'keys':
      return box.keys;
    case 'length':
      return box.length;
    case 'isEmpty':
      return box.isEmpty;
    case 'isNotEmpty':
      return box.isNotEmpty;
    case 'keyAt':
      return box.keyAt(call.arguments['index']);
    case 'watch':
    // TODO
    case 'containsKey':
      return box.containsKey(call.arguments['key']);
    case 'put':
      await box.put(call.arguments['key'], call.arguments['value']);
    case 'putAt':
      await box.putAt(call.arguments['index'], call.arguments['value']);
    case 'putAll':
      await box.putAll(call.arguments['entries']);
    case 'add':
      return await box.add(call.arguments['value']);
    case 'addAll':
      return await box.addAll(call.arguments['values']);
    case 'delete':
      await box.delete(call.arguments['key']);
    case 'deleteAt':
      await box.deleteAt(call.arguments['index']);
    case 'deleteAll':
      await box.deleteAll(call.arguments['keys']);
    case 'compact':
      await box.compact();
    case 'clear':
      await box.clear();
    case 'close':
      await box.close();
    case 'deleteFromDisk':
      await box.deleteFromDisk();
    case 'flush':
      await box.flush();
    case 'values':
      return (box as Box).values;
    case 'valuesBetween':
      return (box as Box).valuesBetween(
        startKey: call.arguments['startKey'],
        endKey: call.arguments['endKey'],
      );
    case 'get':
      if (lazy) {
        return await (box as LazyBox).get(call.arguments['key']);
      } else {
        return (box as Box).get(call.arguments['key']);
      }
    case 'getAt':
      if (lazy) {
        return await (box as LazyBox).getAt(call.arguments['index']);
      } else {
        return (box as Box).getAt(call.arguments['index']);
      }
    case 'toMap':
      return (box as Box).toMap();
    default:
      throw UnimplementedError();
  }
}
