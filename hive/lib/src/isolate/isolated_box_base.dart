import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';

class IsolatedBoxBase<E> implements BoxBase<E> {
  final IsolateMethodChannel _channel;

  @override
  final String name;

  IsolatedBoxBase(this._channel, this.name);

  var _open = true;

  @override
  bool get isOpen => _open;

  @override
  // TODO: implement path
  String? get path => null;

  @override
  // TODO: implement lazy
  bool get lazy => throw UnimplementedError();

  @override
  // TODO: implement keys
  Iterable get keys => throw UnimplementedError();

  @override
  // TODO: implement length
  int get length => throw UnimplementedError();

  @override
  // TODO: implement isEmpty
  bool get isEmpty => throw UnimplementedError();

  @override
  // TODO: implement isNotEmpty
  bool get isNotEmpty => throw UnimplementedError();

  @override
  void keyAt(int index) {
    // TODO: implement keyAt
    throw UnimplementedError();
  }

  @override
  Stream<BoxEvent> watch({key}) {
    // TODO: implement watch
    throw UnimplementedError();
  }

  @override
  bool containsKey(key) {
    // TODO: implement containsKey
    throw UnimplementedError();
  }

  @override
  Future<void> put(key, E value) {
    return _channel.invokeMethod('put', [name, key, value]);
  }

  @override
  Future<void> putAt(int index, E value) {
    // TODO: implement putAt
    throw UnimplementedError();
  }

  @override
  Future<void> putAll(Map<dynamic, E> entries) {
    // TODO: implement putAll
    throw UnimplementedError();
  }

  @override
  Future<int> add(E value) {
    // TODO: implement add
    throw UnimplementedError();
  }

  @override
  Future<Iterable<int>> addAll(Iterable<E> values) {
    // TODO: implement addAll
    throw UnimplementedError();
  }

  @override
  Future<void> delete(key) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAt(int index) {
    // TODO: implement deleteAt
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAll(Iterable keys) {
    // TODO: implement deleteAll
    throw UnimplementedError();
  }

  @override
  Future<void> compact() {
    // TODO: implement compact
    throw UnimplementedError();
  }

  @override
  Future<int> clear() {
    // TODO: implement clear
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFromDisk() {
    // TODO: implement deleteFromDisk
    throw UnimplementedError();
  }

  @override
  Future<void> flush() {
    // TODO: implement flush
    throw UnimplementedError();
  }
}
