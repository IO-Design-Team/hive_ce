import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// Isolated implementation of [BoxBase]
///
/// Most methods are async due to isolate communication
abstract class IsolatedBoxBase<E> {
  final IsolateMethodChannel _channel;
  final IsolateEventChannel _eventChannel;
  Stream<BoxEvent>? _stream;

  /// Constructor
  IsolatedBoxBase(this._channel, this._eventChannel, this.name, this.lazy);

  final String name;

  bool _open = true;

  bool get isOpen => _open;

  Future<String?> get path => _channel.invokeMethod('path', name);

  final bool lazy;

  Future<Iterable> get keys => _channel.invokeMethod('keys', name);

  Future<int> get length => _channel.invokeMethod('length', name);

  Future<bool> get isEmpty => _channel.invokeMethod('isEmpty', name);

  Future<bool> get isNotEmpty => _channel.invokeMethod('isNotEmpty', name);

  Future keyAt(int index) => _channel.invokeMethod('keyAt', name);

  // TODO: Fix this
  Stream<BoxEvent> watch({dynamic key}) => _stream ??= _eventChannel
      .receiveBroadcastStream(key)
      .map((event) => BoxEvent(event['key'], event['value'], event['deleted']));

  Future<bool> containsKey(key) => _channel.invokeMethod('containsKey', name);

  Future<void> put(key, E value) =>
      _channel.invokeMethod('put', {'name': name, 'key': key, 'value': value});

  Future<void> putAt(int index, E value) => _channel
      .invokeMethod('putAt', {'name': name, 'index': index, 'value': value});

  Future<void> putAll(Map<dynamic, E> entries) =>
      _channel.invokeMethod('putAll', {'name': name, 'entries': entries});

  Future<int> add(E value) =>
      _channel.invokeMethod('add', {'name': name, 'value': value});

  Future<Iterable<int>> addAll(Iterable<E> values) =>
      _channel.invokeMethod('addAll', {'name': name, 'values': values});

  Future<void> delete(key) =>
      _channel.invokeMethod('delete', {'name': name, 'key': key});

  Future<void> deleteAt(int index) =>
      _channel.invokeMethod('deleteAt', {'name': name, 'index': index});

  Future<void> deleteAll(Iterable keys) =>
      _channel.invokeMethod('deleteAll', {'name': name, 'keys': keys});

  Future<void> compact() => _channel.invokeMethod('compact', {'name': name});

  Future<int> clear() => _channel.invokeMethod('clear', {'name': name});

  Future<void> close() async {
    await _channel.invokeMethod('close', {'name': name});
    _open = false;
  }

  Future<void> deleteFromDisk() async {
    await _channel.invokeMethod('deleteFromDisk', {'name': name});
    _open = false;
  }

  Future<void> flush() => _channel.invokeMethod('flush', {'name': name});
}

class IsolatedBox<E> extends IsolatedBoxBase<E> {
  /// Constructor
  IsolatedBox(super._channel, super._eventChannel, super.name, super.lazy);

  Future<Iterable<E>> get values => _channel.invokeMethod('values', name);

  Future<Iterable<E>> valuesBetween({startKey, endKey}) =>
      _channel.invokeMethod('valuesBetween', name);

  Future<E?> get(key, {E? defaultValue}) => _channel.invokeMethod('get', name);

  Future<E?> getAt(int index) => _channel.invokeMethod('getAt', name);

  Future<Map<dynamic, E>> toMap() => _channel.invokeMethod('toMap', name);
}
