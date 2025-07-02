import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/connect/hive_connect.dart';
import 'package:hive_ce/src/connect/hive_connect_api.dart';
import 'package:hive_ce/src/connect/inspectable_box.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:meta/meta.dart';

/// Not part of public API
abstract class BoxBaseImpl<E> implements BoxBase<E>, InspectableBox {
  /// TODO: Document this!
  static BoxBase<E> nullImpl<E>() => _NullBoxBase<E>();

  @override
  final String name;

  /// Not part of public API
  @visibleForTesting
  final HiveImpl hive;

  final CompactionStrategy _compactionStrategy;

  /// Not part of public API
  @protected
  final StorageBackend backend;

  /// Not part of public API
  ///
  /// Not `late final` for testing
  @protected
  @visibleForTesting
  late Keystore<E> keystore;

  /// Whether this box is isolated
  final bool isolated;

  var _open = true;

  /// Not part of public API
  BoxBaseImpl(
    this.hive,
    this.name,
    KeyComparator? keyComparator,
    this._compactionStrategy,
    this.backend, {
    this.isolated = false,
  }) {
    keystore = Keystore(this, ChangeNotifier(), keyComparator);
  }

  /// Not part of public API
  Type get valueType => E;

  @override
  bool get isOpen => _open;

  @override
  String? get path => backend.path;

  @override
  Iterable<dynamic> get keys {
    checkOpen();
    return keystore.getKeys();
  }

  @override
  int get length {
    checkOpen();
    return keystore.length;
  }

  @override
  bool get isEmpty => length == 0;

  @override
  bool get isNotEmpty => length > 0;

  /// Not part of public API
  @protected
  void checkOpen() {
    if (!_open) {
      throw HiveError('Box has already been closed.');
    }
  }

  @override
  Stream<BoxEvent> watch({dynamic key}) {
    checkOpen();
    return keystore.watch(key: key);
  }

  @override
  dynamic keyAt(int index) {
    checkOpen();
    return keystore.getAt(index)!.key;
  }

  /// Not part of public API
  Future<void> initialize() {
    return backend.initialize(
      hive,
      keystore,
      lazy,
      isolated: isolated,
    );
  }

  @override
  bool containsKey(dynamic key) {
    checkOpen();
    return keystore.containsKey(key);
  }

  @override
  Future<void> put(dynamic key, E value) => putAll({key: value});

  @override
  Future<void> delete(dynamic key) => deleteAll([key]);

  @override
  Future<int> add(E value) async {
    final key = keystore.autoIncrement();
    await put(key, value);
    return key;
  }

  @override
  Future<Iterable<int>> addAll(Iterable<E> values) async {
    final entries = <int, E>{};
    for (final value in values) {
      entries[keystore.autoIncrement()] = value;
    }
    await putAll(entries);
    return entries.keys;
  }

  @override
  Future<void> putAt(int index, E value) {
    return putAll({keystore.getAt(index)!.key: value});
  }

  @override
  Future<void> deleteAt(int index) {
    return delete(keystore.getAt(index)!.key);
  }

  @override
  Future<int> clear() async {
    checkOpen();

    await backend.clear();
    return keystore.clear();
  }

  @override
  Future<void> compact() async {
    checkOpen();

    if (!backend.supportsCompaction) return;
    if (keystore.deletedEntries == 0) return;

    await backend.compact(keystore.frames);
    keystore.resetDeletedEntries();
  }

  /// Not part of public API
  @protected
  Future<void> performCompactionIfNeeded() {
    if (_compactionStrategy(keystore.length, keystore.deletedEntries)) {
      return compact();
    }

    return Future.value();
  }

  @override
  Future<void> close() async {
    if (!_open) return;

    _open = false;
    await keystore.close();
    hive.unregisterBox(name);
    HiveConnect.unregisterBox(this);

    await backend.close();
  }

  @override
  Future<void> deleteFromDisk() async {
    if (_open) {
      _open = false;
      await keystore.close();
      hive.unregisterBox(name);
    }

    await backend.deleteFromDisk();
  }

  @override
  Future<Iterable<InspectorFrame>> getFrames() async =>
      keystore.frames.map(InspectorFrame.fromFrame);
}

class _NullBoxBase<E> implements BoxBase<E> {
  @override
  Never add(E value) => throw UnimplementedError();

  @override
  Never addAll(Iterable<E> values) => throw UnimplementedError();

  @override
  Never clear() => throw UnimplementedError();

  @override
  Never close() => throw UnimplementedError();

  @override
  Never compact() => throw UnimplementedError();

  @override
  Never containsKey(key) => throw UnimplementedError();

  @override
  Never delete(key) => throw UnimplementedError();

  @override
  Never deleteAll(Iterable keys) => throw UnimplementedError();

  @override
  Never deleteAt(int index) => throw UnimplementedError();

  @override
  Never deleteFromDisk() => throw UnimplementedError();

  @override
  Never get isEmpty => throw UnimplementedError();

  @override
  Never get isNotEmpty => throw UnimplementedError();

  @override
  Never get isOpen => throw UnimplementedError();

  @override
  Never keyAt(int index) => throw UnimplementedError();

  @override
  Never get keys => throw UnimplementedError();

  @override
  Never get lazy => throw UnimplementedError();

  @override
  Never get length => throw UnimplementedError();

  @override
  Never get name => throw UnimplementedError();

  @override
  Never get path => throw UnimplementedError();

  @override
  Never put(key, E value) => throw UnimplementedError();

  @override
  Never putAll(Map<dynamic, E> entries) => throw UnimplementedError();

  @override
  Never putAt(int index, E value) => throw UnimplementedError();

  @override
  Never watch({key}) => throw UnimplementedError();

  @override
  Never flush() => throw UnimplementedError();
}
