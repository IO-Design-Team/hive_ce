import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/backend/js/native/utils.dart';
import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/registry/type_registry_impl.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart';

/// Handles all IndexedDB related tasks
class StorageBackendJs extends StorageBackend {
  static const _bytePrefix = [0x90, 0xA9];
  final IDBDatabase _db;
  final HiveCipher? _cipher;
  final String objectStoreName;

  TypeRegistry _registry;

  /// Not part of public API
  StorageBackendJs(this._db, this._cipher, this.objectStoreName,
      [this._registry = TypeRegistryImpl.nullImpl]);

  @override
  String? get path => null;

  @override
  bool supportsCompaction = false;

  bool _isEncoded(Uint8List bytes) {
    return bytes.length >= _bytePrefix.length &&
        bytes[0] == _bytePrefix[0] &&
        bytes[1] == _bytePrefix[1];
  }

  /// Not part of public API
  @visibleForTesting
  JSAny? encodeValue(Frame frame) {
    var value = frame.value;
    if (_cipher == null) {
      if (value == null) {
        return null;
      } else if (value is Uint8List) {
        if (!_isEncoded(value)) {
          return value.buffer.toJS;
        }
      } else if (value is num) {
        return value.toJS;
      } else if (value is bool) {
        return value.toJS;
      } else if (value is String) {
        return value.toJS;
      } else if (value is List<num>) {
        return value.map((e) => e.toJS).toList().toJS;
      } else if (value is List<bool>) {
        return value.map((e) => e.toJS).toList().toJS;
      } else if (value is List<String>) {
        return value.map((e) => e.toJS).toList().toJS;
      }
    }

    var frameWriter = BinaryWriterImpl(_registry);
    frameWriter.writeByteList(_bytePrefix, writeLength: false);

    if (_cipher == null) {
      frameWriter.write(value);
    } else {
      frameWriter.writeEncrypted(value, _cipher!);
    }

    var bytes = frameWriter.toBytes();
    var sublist = bytes.sublist(0, bytes.length);
    return sublist.buffer.toJS;
  }

  /// Not part of public API
  @visibleForTesting
  Object? decodeValue(JSAny? value) {
    if (value is JSArrayBuffer) {
      var bytes = Uint8List.view(value.toDart);
      if (_isEncoded(bytes)) {
        var reader = BinaryReaderImpl(bytes, _registry);
        reader.skip(2);
        if (_cipher == null) {
          return reader.read();
        } else {
          return reader.readEncrypted(_cipher!);
        }
      } else {
        return bytes;
      }
    } else if (value is JSNumber) {
      return value.toDartDouble;
    } else if (value is JSBoolean) {
      return value.toDart;
    } else if (value is JSString) {
      return value.toDart;
    } else if (value is JSArray) {
      return value.toDart;
    }

    return null;
  }

  /// Not part of public API
  @visibleForTesting
  IDBObjectStore getStore(bool write) {
    return _db
        .transaction(objectStoreName.toJS, write ? 'readwrite' : 'readonly')
        .objectStore(objectStoreName);
  }

  /// Not part of public API
  @visibleForTesting
  Future<List<Object?>> getKeys({bool cursor = false}) async {
    var store = getStore(false);

    if (store.has('getAllKeys') && !cursor) {
      final result = await getStore(false).getAllKeys(null).asFuture();
      return (result as JSArray).toDart.map((e) {
        if (e is JSNumber) {
          return e.toDartInt;
        } else if (e is JSString) {
          return e.toDart;
        }
      }).toList();
    } else {
      final cursors = await store.getCursors();
      return cursors.map((e) => e.key).toList();
    }
  }

  /// Not part of public API
  @visibleForTesting
  Future<Iterable<Object?>> getValues({bool cursor = false}) async {
    var store = getStore(false);

    if (store.has('getAll') && !cursor) {
      final result = await store.getAll(null).asFuture();
      return (result as JSArray).toDart.map(decodeValue);
    } else {
      final cursors = await store.getCursors();
      return cursors.map((e) => e.value).toList();
    }
  }

  @override
  Future<int> initialize(
      TypeRegistry registry, Keystore keystore, bool lazy) async {
    _registry = registry;
    var keys = await getKeys();
    if (!lazy) {
      var i = 0;
      var values = await getValues();
      for (var value in values) {
        var key = keys[i++];
        keystore.insert(Frame(key, value), notify: false);
      }
    } else {
      for (var key in keys) {
        keystore.insert(Frame.lazy(key), notify: false);
      }
    }

    return 0;
  }

  @override
  Future<Object?> readValue(Frame frame) async {
    final value =
        await getStore(false).get(_frameKeyToJS(frame.key)).asFuture();
    return decodeValue(value);
  }

  @override
  Future<void> writeFrames(List<Frame> frames) async {
    var store = getStore(true);
    for (var frame in frames) {
      if (frame.deleted) {
        await store.delete(_frameKeyToJS(frame.key)).asFuture();
      } else {
        await store
            .put(encodeValue(frame), _frameKeyToJS(frame.key))
            .asFuture();
      }
    }
  }

  @override
  Future<List<Frame>> compact(Iterable<Frame> frames) {
    throw UnsupportedError('Not supported');
  }

  @override
  Future<void> clear() {
    return getStore(true).clear().asFuture();
  }

  @override
  Future<void> close() {
    _db.close();
    return Future.value();
  }

  @override
  Future<void> deleteFromDisk() async {
    final indexDB = window.self.indexedDB;

    print('Delete ${_db.name} // $objectStoreName from disk');

    // directly deleting the entire DB if a non-collection Box
    if (_db.objectStoreNames.length == 1) {
      await indexDB.deleteDatabase(_db.name).asFuture();
    } else {
      final request = indexDB.open(_db.name, 1);
      request.onupgradeneeded = (IDBVersionChangeEvent e) {
        var db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
        if (db.objectStoreNames.contains(objectStoreName)) {
          db.deleteObjectStore(objectStoreName);
        }
      }.toJS;
      final db = request.asFuture() as IDBDatabase;
      if (db.objectStoreNames.length == 0) {
        await indexDB.deleteDatabase(_db.name).asFuture();
      }
    }
  }

  @override
  Future<void> flush() => Future.value();

  JSAny _frameKeyToJS(Object? key) {
    if (key is int) {
      return key.toJS;
    } else if (key is String) {
      return key.toJS;
    } else {
      throw HiveError('Invalid key type');
    }
  }
}
