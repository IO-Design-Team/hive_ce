import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/storage_backend_memory.dart';
import 'package:hive_ce/src/box/box_base_impl.dart';
import 'package:hive_ce/src/box/box_impl.dart';
import 'package:hive_ce/src/box/default_compaction_strategy.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/box/lazy_box_impl.dart';
import 'package:hive_ce/src/connect/hive_connect.dart';
import 'package:hive_ce/src/isolate/isolate_debug_name/isolate_debug_name.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate_name.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:hive_ce/src/util/type_utils.dart';
import 'package:meta/meta.dart';

import 'package:hive_ce/src/backend/storage_backend.dart';

/// Not part of public API
class HiveImpl extends TypeRegistryImpl implements HiveInterface {
  /// Warning message printed when accessing Hive from an unsafe isolate
  @visibleForTesting
  static final unsafeIsolateWarning = '''
⚠️ WARNING: HIVE MULTI-ISOLATE RISK DETECTED ⚠️

Accessing Hive from an unsafe isolate (current isolate: "$isolateDebugName")
This can lead to DATA CORRUPTION as Hive boxes are not designed for concurrent
access across isolates. Each isolate would maintain its own box cache,
potentially causing data inconsistency and corruption.

RECOMMENDED ACTIONS:
- Use IsolatedHive instead

''';

  static final BackendManagerInterface _defaultBackendManager =
      BackendManager.select();

  final _boxes = HashMap<String, BoxBaseImpl>();
  final _openingBoxes = HashMap<String, Future>();
  BackendManagerInterface? _managerOverride;
  final _secureRandom = Random.secure();

  /// Whether this Hive instance is isolated
  var _isolated = false;

  /// Whether box names should be obfuscated when stored on disk
  var _obfuscateBoxNames = false;

  /// Set [_isolated] to true
  void setIsolated() => _isolated = true;

  /// Not part of public API
  @visibleForTesting
  String? homePath;

  /// either returns the preferred [BackendManagerInterface] or the
  /// platform default fallback
  BackendManagerInterface get _manager =>
      _managerOverride ?? _defaultBackendManager;

  @override
  void init(
    String? path, {
    HiveStorageBackendPreference backendPreference =
        HiveStorageBackendPreference.native,
    bool obfuscateBoxNames = false,
  }) {
    if (!{'main', hiveIsolateName}.contains(isolateDebugName)) {
      debugPrint(unsafeIsolateWarning);
    }
    homePath = path;
    _obfuscateBoxNames = obfuscateBoxNames;
    _managerOverride =
        BackendManager.select(backendPreference, obfuscateBoxNames);
  }

  Future<BoxBase<E>> _openBox<E>(
    String name,
    bool lazy,
    HiveCipher? cipher,
    KeyComparator comparator,
    CompactionStrategy compaction,
    bool recovery,
    String? path,
    Uint8List? bytes,
    String? collection,
  ) async {
    assert(path == null || bytes == null);
    assert(
      name.length <= 255 && name.isAscii,
      'Box names need to be ASCII Strings with a max length of 255.',
    );
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

      BoxBaseImpl<E>? newBox;
      try {
        StorageBackend backend;
        if (bytes != null) {
          backend = StorageBackendMemory(bytes, cipher);
        } else {
          backend = await _manager.open(
            name,
            path ?? homePath,
            recovery,
            cipher,
            collection,
            _obfuscateBoxNames,
          );
        }

        if (lazy) {
          newBox = LazyBoxImpl<E>(
            this,
            name,
            comparator,
            compaction,
            backend,
            isolated: _isolated,
          );
        } else {
          newBox = BoxImpl<E>(
            this,
            name,
            comparator,
            compaction,
            backend,
            isolated: _isolated,
          );
        }

        await newBox.initialize();
        _boxes[name] = newBox;

        completer.complete();

        if (!_isolated) HiveConnect.registerBox(newBox);

        return newBox;
      } catch (error, stackTrace) {
        newBox?.close().ignore();
        completer.completeError(error, stackTrace);
        rethrow;
      } finally {
        _openingBoxes.remove(name)?.ignore();
      }
    }
  }

  @override
  Future<Box<E>> openBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    Uint8List? bytes,
    String? collection,
    @Deprecated('Use encryptionCipher instead') List<int>? encryptionKey,
  }) async {
    if (encryptionKey != null) {
      encryptionCipher = HiveAesCipher(encryptionKey);
    }
    return await _openBox<E>(
      name,
      false,
      encryptionCipher,
      keyComparator,
      compactionStrategy,
      crashRecovery,
      path,
      bytes,
      collection,
    ) as Box<E>;
  }

  @override
  Future<LazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
    @Deprecated('Use encryptionCipher instead') List<int>? encryptionKey,
  }) async {
    if (encryptionKey != null) {
      encryptionCipher = HiveAesCipher(encryptionKey);
    }
    return await _openBox<E>(
      name,
      true,
      encryptionCipher,
      keyComparator,
      compactionStrategy,
      crashRecovery,
      path,
      null,
      collection,
    ) as LazyBox<E>;
  }

  BoxBase<E> _getBoxInternal<E>(String name, [bool? lazy]) {
    final lowerCaseName = name.toLowerCase();
    final box = _boxes[lowerCaseName];
    if (box != null) {
      if ((lazy == null || box.lazy == lazy) && box.valueType == E) {
        return box as BoxBase<E>;
      } else {
        final typeName = box is LazyBox
            ? 'LazyBox<${box.valueType}>'
            : 'Box<${box.valueType}>';
        throw HiveError('The box "$lowerCaseName" is already open '
            'and of type $typeName.');
      }
    } else {
      throw HiveError('Box not found. Did you forget to call Hive.openBox()?');
    }
  }

  /// Not part of public API
  BoxBase? getBoxWithoutCheckInternal(String name) {
    final lowerCaseName = name.toLowerCase();
    return _boxes[lowerCaseName];
  }

  @override
  Box<E> box<E>(String name) => _getBoxInternal<E>(name, false) as Box<E>;

  @override
  LazyBox<E> lazyBox<E>(String name) =>
      _getBoxInternal<E>(name, true) as LazyBox<E>;

  @override
  bool isBoxOpen(String name) {
    return _boxes.containsKey(name.toLowerCase());
  }

  @override
  Future<void> close() {
    final closeFutures = _boxes.values.map((box) {
      return box.close();
    });

    return Future.wait(closeFutures);
  }

  /// Not part of public API
  void unregisterBox(String name) {
    name = name.toLowerCase();
    _openingBoxes.remove(name);
    _boxes.remove(name);
  }

  @override
  Future<void> deleteBoxFromDisk(
    String name, {
    String? path,
    String? collection,
  }) async {
    final lowerCaseName = name.toLowerCase();
    final box = _boxes[lowerCaseName];
    if (box != null) {
      await box.deleteFromDisk();
    } else {
      await _manager.deleteBox(
        lowerCaseName,
        path ?? homePath,
        collection,
        _obfuscateBoxNames,
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
  List<int> generateSecureKey() {
    return _secureRandom.nextBytes(32);
  }

  @override
  Future<bool> boxExists(
    String name, {
    String? path,
    String? collection,
  }) async {
    final lowerCaseName = name.toLowerCase();
    return await _manager.boxExists(
      lowerCaseName,
      path ?? homePath,
      collection,
      _obfuscateBoxNames,
    );
  }
}
