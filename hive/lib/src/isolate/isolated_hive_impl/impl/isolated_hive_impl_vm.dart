import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/connect/hive_connect.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:hive_ce/src/isolate/isolated_box_impl/isolated_box_impl_vm.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate_name.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:hive_ce/src/util/logger.dart';
import 'package:hive_ce/src/util/type_utils.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// Handles Hive operations in an isolate
class IsolatedHiveImpl extends TypeRegistryImpl
    implements IsolatedHiveInterface, HiveIsolate {
  late final IsolateNameServer? _isolateNameServer;

  IsolateConnection? _connection;

  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

  final _boxes = <String, IsolatedBoxBaseImpl>{};
  final _openingBoxes = <String, Future>{};

  @override
  IsolateConnection get connection => _connection!;

  late Future<IsolateConnection> Function() _spawnHiveIsolate =
      () => spawnIsolate(
            isolateEntryPoint,
            debugName: hiveIsolateName,
            onConnect: onConnect,
            onExit: onExit,
          );

  @override
  void onConnect(SendPort send) {
    _isolateNameServer?.removePortNameMapping(hiveIsolateName);
    _isolateNameServer?.registerPortWithName(send, hiveIsolateName);
  }

  @override
  void onExit() => _isolateNameServer?.removePortNameMapping(hiveIsolateName);

  @override
  set spawnHiveIsolate(Future<IsolateConnection> Function() spawnHiveIsolate) =>
      _spawnHiveIsolate = spawnHiveIsolate;

  @override
  Future<void> init(
    String? path, {
    IsolateNameServer? isolateNameServer,
  }) async {
    if (_connection == null) {
      _isolateNameServer = isolateNameServer;

      if (Logger.noIsolateNameServerWarning && _isolateNameServer == null) {
        Logger.w(HiveWarning.noIsolateNameServer);
      }

      final send =
          _isolateNameServer?.lookupPortByName(hiveIsolateName) as SendPort?;

      IsolateConnection connection;
      if (send != null) {
        try {
          var connectFuture = connectToIsolate(send);

          // Sometimes the INS does not get cleared on a hot restart
          // This results in the send port being stale
          // This would be unsafe in release mode
          if (kDebugMode) {
            connectFuture =
                connectFuture.timeout(const Duration(milliseconds: 50));
          }
          connection = await connectFuture;
        } on TimeoutException {
          connection = await _spawnHiveIsolate();
        }
      } else {
        connection = await _spawnHiveIsolate();
      }
      _connection = connection;

      _hiveChannel = IsolateMethodChannel('hive', connection);
      _boxChannel = IsolateMethodChannel('box', connection);
    }

    return _hiveChannel.invokeMethod(
      'init',
      {'path': path, 'logger_level': Logger.level.name},
    );
  }

  Future<IsolatedBoxBase<E>> _openBox<E>(
    String name,
    bool lazy,
    HiveCipher? cipher,
    KeyComparator? comparator,
    CompactionStrategy? compaction,
    bool recovery,
    String? path,
    Uint8List? bytes,
    String? collection,
  ) async {
    final connection = _connection;
    if (connection == null) {
      throw HiveError('IsolatedHive is not initialized');
    }

    typedMapOrIterableCheck<E>();

    name = name.toLowerCase();
    if (isBoxOpen(name)) {
      if (lazy) {
        return lazyBox(name);
      } else {
        return box(name);
      }
    } else {
      if (_openingBoxes.containsKey(name)) {
        await _openingBoxes[name];
        if (lazy) {
          return lazyBox(name);
        } else {
          return box(name);
        }
      }

      final completer = Completer();
      _openingBoxes[name] = completer.future;

      try {
        final params = {
          'name': name,
          'lazy': lazy,
          'keyCrc': cipher?.calculateKeyCrc(),
          'keyComparator': comparator,
          'compactionStrategy': compaction,
          'crashRecovery': recovery,
          'path': path,
          'bytes': bytes,
          'collection': collection,
        };

        await _hiveChannel.invokeMethod('openBox', params);

        final newBox = lazy
            ? IsolatedLazyBoxImpl<E>(
                this,
                name,
                cipher,
                connection,
                _boxChannel,
              )
            : IsolatedBoxImpl<E>(
                this,
                name,
                cipher,
                connection,
                _boxChannel,
              );

        _boxes[name] = newBox;

        completer.complete();

        HiveConnect.registerBox(newBox);

        return newBox;
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
        rethrow;
      } finally {
        _openingBoxes.remove(name)?.ignore();
      }
    }
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
  }) async =>
      await _openBox<E>(
        name,
        false,
        encryptionCipher,
        keyComparator,
        compactionStrategy,
        crashRecovery,
        path,
        bytes,
        collection,
      ) as IsolatedBox<E>;

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
      await _openBox<E>(
        name,
        true,
        encryptionCipher,
        keyComparator,
        compactionStrategy,
        crashRecovery,
        path,
        null,
        collection,
      ) as IsolatedLazyBox<E>;

  IsolatedBoxBase<E> _getBoxInternal<E>(String name, bool lazy) {
    final lowerCaseName = name.toLowerCase();
    final box = _boxes[lowerCaseName];
    if (box != null) {
      if (box.lazy == lazy && box.valueType == E) {
        return box as IsolatedBoxBase<E>;
      } else {
        final typeName = box is IsolatedLazyBox
            ? 'IsolatedLazyBox<${box.valueType}>'
            : 'IsolatedBox<${box.valueType}>';
        throw HiveError('The box "$lowerCaseName" is already open '
            'and of type $typeName.');
      }
    } else {
      throw HiveError(
        'Box not found. Did you forget to call IsolatedHive.openBox()?',
      );
    }
  }

  @override
  IsolatedBox<E> box<E>(String name) =>
      _getBoxInternal<E>(name, false) as IsolatedBox<E>;

  @override
  IsolatedLazyBox<E> lazyBox<E>(String name) =>
      _getBoxInternal<E>(name, true) as IsolatedLazyBox<E>;

  @override
  bool isBoxOpen(String name) => _boxes.containsKey(name.toLowerCase());

  @override
  Future<void> close() {
    final closeFutures = _boxes.values.map((box) {
      return box.close();
    });

    return Future.wait(closeFutures);
  }

  /// Not part of public API
  Future<void> unregisterBox(String name) async {
    name = name.toLowerCase();
    _openingBoxes.remove(name)?.ignore();
    _boxes.remove(name);
    await _hiveChannel.invokeMethod('unregisterBox', {'name': name});
  }

  @override
  Future<void> deleteBoxFromDisk(String name, {String? path}) async {
    final lowerCaseName = name.toLowerCase();
    final box = _boxes[lowerCaseName];
    if (box != null) {
      await box.deleteFromDisk();
    } else {
      await _hiveChannel.invokeMethod(
        'deleteBoxFromDisk',
        {'name': name.toLowerCase(), 'path': path},
      );
    }
  }

  @override
  Future<void> deleteFromDisk() {
    final deleteFutures = _boxes.values.toList().map((box) {
      return box.deleteFromDisk();
    });

    return Future.wait(deleteFutures);
  }

  @override
  Future<bool> boxExists(String name, {String? path}) => _hiveChannel
      .invokeMethod('boxExists', {'name': name.toLowerCase(), 'path': path});
}
