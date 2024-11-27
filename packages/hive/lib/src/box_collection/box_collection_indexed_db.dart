import 'dart:async';
import 'dart:js_interop';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/js/native/utils.dart';
import 'package:hive_ce/src/box_collection/box_collection_stub.dart'
    as implementation;
import 'package:web/web.dart';

/// represents a [BoxCollection] for raw use with indexed DB
class BoxCollection implements implementation.BoxCollection {
  final IDBDatabase _db;
  @override
  final Set<String> boxNames;

  /// TODO: Document this!
  BoxCollection(this._db, this.boxNames);

  /// TODO: Document this!
  static Future<BoxCollection> open(
    String name,
    Set<String> boxNames, {
    String? path,
    HiveCipher? key,
  }) async {
    final request = window.self.indexedDB.open(name, 1);
    request.onupgradeneeded = (IDBVersionChangeEvent event) {
      final db = (event.target as IDBOpenDBRequest).result as IDBDatabase;
      for (final name in boxNames) {
        db.createObjectStore(
          name,
          IDBObjectStoreParameters(autoIncrement: true),
        );
      }
    }.toJS;
    final db = await request.asFuture<IDBDatabase>();
    return BoxCollection(db, boxNames);
  }

  @override
  String get name => _db.name;

  @override
  Future<CollectionBox<V>> openBox<V>(
    String name, {
    bool preload = false,
    implementation.CollectionBox<V> Function(String, BoxCollection)? boxCreator,
  }) async {
    if (!boxNames.contains(name)) {
      throw Exception(
        'Box with name $name is not in the known box names of this collection.',
      );
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
      unawaited(fun(txn));
    }
    final completer = Completer<void>();
    txn.oncomplete = (Event e) {
      completer.complete();
    }.toJS;
    return;
  }

  @override
  void close() => _db.close();

  @override
  Future<void> deleteFromDisk() async {
    for (final box in _openBoxes) {
      box._cache.clear();
      box._cachedKeys = null;
    }
    _openBoxes.clear();
    _db.close();
    window.self.indexedDB.deleteDatabase(_db.name);
  }
}

/// TODO: Document this!
class CollectionBox<V> implements implementation.CollectionBox<V> {
  @override
  final String name;
  @override
  final BoxCollection boxCollection;
  final Map<String, V?> _cache = {};
  Set<String>? _cachedKeys;

  /// TODO: Document this!
  CollectionBox(this.name, this.boxCollection);

  @override
  Future<List<String>> getAllKeys([IDBTransaction? txn]) async {
    final cachedKey = _cachedKeys;
    if (cachedKey != null) return cachedKey.toList();
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final result = await store.getAllKeys(null).asFuture<JSArray>();
    final keys =
        List<String>.from(result.toDart.cast<JSString>().map((e) => e.toDart));
    _cachedKeys = keys.toSet();
    return keys;
  }

  @override
  Future<Map<String, V>> getAllValues([IDBTransaction? txn]) async {
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final map = <String, V>{};
    await for (final entry in store.iterate()) {
      map[(entry.key as JSString).toDart] = entry.value.dartify() as V;
    }
    return map;
  }

  @override
  Future<V?> get(String key, [IDBTransaction? txn]) async {
    if (_cache.containsKey(key)) return _cache[key];
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final value = await store.get(key.toJS).asFuture();
    _cache[key] = value.dartify() as V?;
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
      _cache[keys[i]] = list[i].dartify() as V?;
    }
    return list.cast<V?>();
  }

  @override
  Future<void> put(String key, V val, [Object? transaction]) async {
    IDBTransaction? txn;
    if ((transaction as JSAny?).isA<IDBTransaction>()) {
      txn = transaction as IDBTransaction;
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
    await store.put(val.jsify(), key.toJS).asFuture();
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
      for (final key in keys) {
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
