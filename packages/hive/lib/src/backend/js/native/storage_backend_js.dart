import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart';

/// Handles all IndexedDB related tasks
class StorageBackendJs extends StorageBackend {
  static const _bytePrefix = [0x90, 0xA9];
  final IDBDatabase _db;
  final HiveCipher? _cipher;

  /// TODO: Document this!
  final String objectStoreName;

  TypeRegistry _registry;

  /// Not part of public API
  StorageBackendJs(
    this._db,
    this._cipher,
    this.objectStoreName, [
    this._registry = TypeRegistryImpl.nullImpl,
  ]);

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
    final value = frame.value;
    if (_cipher == null) {
      if (value == null) {
        return null;
      } else if (value is Uint8List) {
        if (!_isEncoded(value)) {
          return value.buffer.toJS;
        }
      } else if (value is num ||
          value is bool ||
          value is String ||
          value is List<num> ||
          value is List<bool> ||
          value is List<String>) {
        return value.jsify();
      }
    }

    final frameWriter = BinaryWriterImpl(_registry);
    frameWriter.writeByteList(_bytePrefix, writeLength: false);

    if (_cipher == null) {
      frameWriter.write(value);
    } else {
      frameWriter.writeEncrypted(value, _cipher);
    }

    final bytes = frameWriter.toBytes();
    final sublist = bytes.sublist(0, bytes.length);
    return sublist.buffer.toJS;
  }

  /// Not part of public API
  @visibleForTesting
  Object? decodeValue(JSAny? value) {
    if (value.isA<JSArrayBuffer>()) {
      value as JSArrayBuffer;
      final bytes = Uint8List.view(value.toDart);
      if (_isEncoded(bytes)) {
        final reader = BinaryReaderImpl(bytes, _registry);
        reader.skip(2);
        if (_cipher == null) {
          return reader.read();
        } else {
          return reader.readEncrypted(_cipher);
        }
      } else {
        return bytes;
      }
    } else {
      return value.dartify();
    }
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
    final store = getStore(false);

    if (store.has('getAllKeys') && !cursor) {
      final result = await getStore(false).getAllKeys(null).asFuture<JSArray>();
      return result.toDart.map((e) {
        if (e.isA<JSNumber>()) {
          e as JSNumber;
          return e.toDartInt;
        } else if (e.isA<JSString>()) {
          e as JSString;
          return e.toDart;
        }
      }).toList();
    } else {
      return store.iterate().map((e) => e.key.dartify()).toList();
    }
  }

  /// Not part of public API
  @visibleForTesting
  Future<Iterable<Object?>> getValues({bool cursor = false}) async {
    final store = getStore(false);

    if (store.has('getAll') && !cursor) {
      final result = await store.getAll(null).asFuture<JSArray>();
      return result.toDart.map(decodeValue);
    } else {
      return store.iterate().map((e) => e.value.dartify()).toList();
    }
  }

  @override
  Future<int> initialize(
    TypeRegistry registry,
    Keystore keystore,
    bool lazy,
  ) async {
    _registry = registry;
    final keys = await getKeys();
    if (!lazy) {
      var i = 0;
      final values = await getValues();
      for (final value in values) {
        final key = keys[i++];
        keystore.insert(Frame(key, value), notify: false);
      }
    } else {
      for (final key in keys) {
        keystore.insert(Frame.lazy(key), notify: false);
      }
    }

    return 0;
  }

  @override
  Future<Object?> readValue(Frame frame) async {
    final value = await getStore(false).get(frame.key.jsify()).asFuture();
    return decodeValue(value);
  }

  @override
  Future<void> writeFrames(List<Frame> frames) async {
    final store = getStore(true);
    for (final frame in frames) {
      if (frame.deleted) {
        await store.delete(frame.key.jsify()).asFuture();
      } else {
        await store.put(encodeValue(frame), frame.key.jsify()).asFuture();
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
        final db = (e.target as IDBOpenDBRequest).result as IDBDatabase;
        if (db.objectStoreNames.contains(objectStoreName)) {
          db.deleteObjectStore(objectStoreName);
        }
      }.toJS;
      final db = await request.asFuture<IDBDatabase>();
      if (db.objectStoreNames.length == 0) {
        await indexDB.deleteDatabase(_db.name).asFuture();
      }
    }
  }

  @override
  Future<void> flush() => Future.value();
}
