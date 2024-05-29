import 'dart:async';
import 'dart:js_interop';

import 'package:hive/hive.dart';
import 'package:hive/src/backend/js/native/utils.dart';
import 'package:hive/src/box_collection/box_collection_stub.dart'
    as implementation;
import 'package:web/web.dart';

/// represents a [BoxCollection] for raw use with indexed DB
class BoxCollection implements implementation.BoxCollection {
  final IDBDatabase _db;
  @override
  final Set<String> boxNames;

  BoxCollection(this._db, this.boxNames);

  static Future<BoxCollection> open(
    String name,
    Set<String> boxNames, {
    dynamic path,
    HiveCipher? key,
  }) async {
    final factory = window.indexedDB;
    final request = factory.open(name, 1);
    request.onupgradeneeded = (event) {
      final _db = event.target.result as IDBDatabase;
      for (final name in boxNames) {
        _db.createObjectStore(
          name,
          IDBObjectStoreParameters(autoIncrement: true),
        );
      }
    }.toJS;
    final _db = await request.asFuture() as IDBDatabase;
    return BoxCollection(_db, boxNames);
  }

  @override
  String get name => _db.name;

  @override
  Future<CollectionBox<V>> openBox<V>(String name,
      {bool preload = false,
      implementation.CollectionBox<V> Function(String, BoxCollection)?
          boxCreator}) async {
    if (!boxNames.contains(name)) {
      throw Exception(
          'Box with name $name is not in the known box names of this collection.');
    }
    final i = _openBoxes.indexWhere((box) => box.name == name);
    if (i != -1) {
      return _openBoxes[i] as CollectionBox<V>;
    }
    final box = boxCreator?.call(name, this) as CollectionBox<V>? ??
        CollectionBox<V>(name, this);
    if (preload) {
      box._cache.addAll(await box.getAllValues());
    }
    _openBoxes.add(box);
    return box;
  }

  final List<CollectionBox> _openBoxes = [];

  List<Future<void> Function(IDBTransaction txn)>? _txnCache;

  @override
  Future<void> transaction(
    Future<void> Function() action, {
    List<String>? boxNames,
    bool readOnly = false,
  }) async {
    boxNames ??= this.boxNames.toList();
    if (_txnCache != null) {
      await action();
      return;
    }
    _txnCache = [];
    await action();
    final cache =
        List<Future<void> Function(IDBTransaction txn)>.from(_txnCache ?? []);
    _txnCache = null;
    if (cache.isEmpty) return;
    final txn = _db.transaction(
      boxNames.map((e) => e.toJS).toList().toJS,
      readOnly ? 'readonly' : 'readwrite',
    );
    for (final fun in cache) {
      fun(txn);
    }
    final completer = Completer<void>();
    txn.oncomplete = (_) {
      completer.complete();
    }.toJS;
    return;
  }

  @override
  void close() => _db.close();

  @override
  Future<void> deleteFromDisk() async {
    final factory = window.indexedDB;
    for (final box in _openBoxes) {
      box._cache.clear();
      box._cachedKeys = null;
    }
    _openBoxes.clear();
    _db.close();
    factory.deleteDatabase(_db.name);
  }
}

class CollectionBox<V> implements implementation.CollectionBox<V> {
  @override
  final String name;
  @override
  final BoxCollection boxCollection;
  final Map<String, V?> _cache = {};
  Set<String>? _cachedKeys;

  CollectionBox(this.name, this.boxCollection) {
    if (!(V is String ||
        V is int ||
        V is List<Object?> ||
        V is Map<String, Object?> ||
        V is double)) {
      throw Exception(
          'Value type ${V.runtimeType} is not one of the allowed value types {String, int, double, List<Object?>, Map<String, Object?>}.');
    }
  }

  @override
  Future<List<String>> getAllKeys([IDBTransaction? txn]) async {
    final cachedKey = _cachedKeys;
    if (cachedKey != null) return cachedKey.toList();
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final result = await store.getAllKeys(null).asFuture() as List;
    final List<String> keys = List.from(result.cast<String>() as Iterable);
    _cachedKeys = keys.toSet();
    return keys;
  }

  @override
  Future<Map<String, V>> getAllValues([IDBTransaction? txn]) async {
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final map = <String, V>{};
    final cursors = await store.getCursors();
    for (final cursor in cursors) {
      map[cursor.key as String] = cursor.value as V;
    }
    return map;
  }

  @override
  Future<V?> get(String key, [IDBTransaction? txn]) async {
    if (_cache.containsKey(key)) return _cache[key];
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    _cache[key] = await store.get(key.toJS).asFuture() as V?;
    return _cache[key];
  }

  @override
  Future<List<V?>> getAll(List<String> keys, [IDBTransaction? txn]) async {
    if (!keys.any((key) => !_cache.containsKey(key))) {
      return keys.map((key) => _cache[key]).toList();
    }
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final list =
        await Future.wait(keys.map((e) => store.get(e.toJS).asFuture()));
    for (var i = 0; i < keys.length; i++) {
      _cache[keys[i]] = list[i] as V?;
    }
    return list.cast<V?>();
  }

  @override
  Future<void> put(String key, V val, [Object? transaction]) async {
    IDBTransaction? txn;
    if (transaction is IDBTransaction) {
      txn = transaction;
    }
    if (val == null) {
      return delete(key, txn);
    }
    final txnCache = boxCollection._txnCache;
    if (txnCache != null) {
      txnCache.add((txn) => put(key, val, txn));
      _cache[key] = val;
      _cachedKeys?.add(key);
      return;
    }

    txn ??= boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    await store.put(val.toJSBox, key.toJS).asFuture();
    _cache[key] = val;
    _cachedKeys?.add(key);
    return;
  }

  @override
  Future<void> delete(String key, [IDBTransaction? txn]) async {
    final txnCache = boxCollection._txnCache;
    if (txnCache != null) {
      txnCache.add((txn) => delete(key, txn));
      _cache[key] = null;
      _cachedKeys?.remove(key);
      return;
    }

    txn ??= boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    await store.delete(key.toJS).asFuture();
    _cache[key] = null;
    _cachedKeys?.remove(key);
    return;
  }

  @override
  Future<void> deleteAll(List<String> keys, [IDBTransaction? txn]) async {
    final txnCache = boxCollection._txnCache;
    if (txnCache != null) {
      txnCache.add((txn) => deleteAll(keys, txn));
      for (var key in keys) {
        _cache[key] = null;
      }
      _cachedKeys?.removeAll(keys);
      return;
    }

    txn ??= boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    for (final key in keys) {
      await store.delete(key.toJS).asFuture();
      _cache[key] = null;
      _cachedKeys?.removeAll(keys);
    }
    return;
  }

  @override
  Future<void> clear([IDBTransaction? txn]) async {
    final txnCache = boxCollection._txnCache;
    if (txnCache != null) {
      txnCache.add(clear);
      _cache.clear();
      _cachedKeys = null;
      return;
    }

    txn ??= boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    await store.clear().asFuture();
    _cache.clear();
    _cachedKeys = null;
    return;
  }

  @override
  Future<void> flush() => Future.value();
}
