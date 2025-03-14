import 'dart:async';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:hive_ce/src/isolate/isolated_box_impl/isolated_box_impl_vm.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// Handles Hive operations in an isolate
///
/// Limitations:
/// - [IsolatedHive] does not support [HiveObject]s
/// - Most methods are async due to isolate communication
class IsolatedHiveImpl extends TypeRegistryImpl
    implements IsolatedHiveInterface, HiveIsolate {
  late final IsolateNameServer? _isolateNameServer;
  late final IsolateMethodChannel _hiveChannel;
  late final IsolateMethodChannel _boxChannel;

  late final IsolateConnection _connection;

  final _boxes = <String, IsolatedBoxBaseImpl>{};
  final _openingBoxes = <String, Future>{};

  @override
  IsolateConnection get connection => _connection;

  IsolateEntryPoint _entryPoint = isolateEntryPoint;

  @override
  set entryPoint(IsolateEntryPoint entryPoint) => _entryPoint = entryPoint;

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
      _connection = connectToIsolate(send);
    } else {
      _connection = await spawnIsolate(
        _entryPoint,
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

    _hiveChannel = IsolateMethodChannel('hive', _connection);
    _boxChannel = IsolateMethodChannel('box', _connection);

    return _hiveChannel.invokeMethod('init', path);
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
          'encryptionCipher': cipher,
          'keyComparator': comparator,
          'compactionStrategy': compaction,
          'crashRecovery': recovery,
          'path': path,
          'bytes': bytes,
          'collection': collection,
        };

        final IsolatedBoxBaseImpl<E> newBox;
        if (lazy) {
          await _hiveChannel.invokeMethod('openLazyBox', params);
          newBox = IsolatedLazyBoxImpl<E>(
            this,
            name,
            cipher,
            _connection,
            _boxChannel,
          );
        } else {
          await _hiveChannel.invokeMethod('openBox', params);
          newBox = IsolatedBoxImpl<E>(
            this,
            name,
            cipher,
            _connection,
            _boxChannel,
          );
        }

        _boxes[name] = newBox;

        completer.complete();
        return newBox;
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
        rethrow;
      } finally {
        unawaited(_openingBoxes.remove(name));
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
  Future<void> close() async {
    if (!_open) return;
    await _hiveChannel.invokeMethod('close');
    _connection.close();
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
}
