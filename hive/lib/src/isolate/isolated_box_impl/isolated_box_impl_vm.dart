import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// Isolated implementation of [BoxBase]
///
/// Most methods are async due to isolate communication
abstract class IsolatedBoxBaseImpl<E> implements IsolatedBoxBase<E> {
  final IsolateMethodChannel _channel;
  final IsolateEventChannel _eventChannel;
  Stream<BoxEvent>? _stream;

  /// Constructor
  IsolatedBoxBaseImpl(
    this._channel,
    IsolateConnection connection,
    this.name,
    this.lazy,
  ) : _eventChannel = IsolateEventChannel('box_$name', connection);

  @override
  final String name;

  @override
  final bool lazy;

  @override
  Future<bool> get isOpen => _channel.invokeMethod('isOpen', {'name': name});

  @override
  Future<String?> get path => _channel.invokeMethod('path', {'name': name});

  @override
  Future<Iterable> get keys => _channel.invokeMethod('keys', {'name': name});

  @override
  Future<int> get length => _channel.invokeMethod('length', {'name': name});

  @override
  Future<bool> get isEmpty => _channel.invokeMethod('isEmpty', {'name': name});

  @override
  Future<bool> get isNotEmpty =>
      _channel.invokeMethod('isNotEmpty', {'name': name});

  @override
  Future keyAt(int index) =>
      _channel.invokeMethod('keyAt', {'name': name, 'index': index});

  @override
  Stream<BoxEvent> watch({dynamic key}) => _stream ??= _eventChannel
      .receiveBroadcastStream()
      .cast<BoxEvent>()
      .where((event) => key == null || event.key == key);

  @override
  Future<bool> containsKey(dynamic key) =>
      _channel.invokeMethod('containsKey', {'name': name, 'key': key});

  @override
  Future<void> put(dynamic key, E value) =>
      _channel.invokeMethod('put', {'name': name, 'key': key, 'value': value});

  @override
  Future<void> putAt(int index, E value) => _channel
      .invokeMethod('putAt', {'name': name, 'index': index, 'value': value});

  @override
  Future<void> putAll(Map<dynamic, E> entries) =>
      _channel.invokeMethod('putAll', {'name': name, 'entries': entries});

  @override
  Future<int> add(E value) =>
      _channel.invokeMethod('add', {'name': name, 'value': value});

  @override
  Future<Iterable<int>> addAll(Iterable<E> values) =>
      _channel.invokeMethod('addAll', {'name': name, 'values': values});

  @override
  Future<void> delete(dynamic key) =>
      _channel.invokeMethod('delete', {'name': name, 'key': key});

  @override
  Future<void> deleteAt(int index) =>
      _channel.invokeMethod('deleteAt', {'name': name, 'index': index});

  @override
  Future<void> deleteAll(Iterable keys) =>
      _channel.invokeMethod('deleteAll', {'name': name, 'keys': keys});

  @override
  Future<void> compact() => _channel.invokeMethod('compact', {'name': name});

  @override
  Future<int> clear() => _channel.invokeMethod('clear', {'name': name});

  @override
  Future<void> close() => _channel.invokeMethod('close', {'name': name});

  @override
  Future<void> deleteFromDisk() =>
      _channel.invokeMethod('deleteFromDisk', {'name': name});

  @override
  Future<void> flush() => _channel.invokeMethod('flush', {'name': name});

  @override
  Future<E?> get(dynamic key, {E? defaultValue}) =>
      _channel.invokeMethod('get', {
        'name': name,
        'key': key,
        'defaultValue': defaultValue,
      });

  @override
  Future<E?> getAt(int index) =>
      _channel.invokeMethod('getAt', {'name': name, 'index': index});
}

/// Isolated implementation of [Box]
class IsolatedBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedBox<E> {
  /// Constructor
  IsolatedBoxImpl(super._channel, super.connection, super.name, super.lazy);

  @override
  Future<Iterable<E>> get values =>
      _channel.invokeMethod('values', {'name': name});

  @override
  Future<Iterable<E>> valuesBetween({dynamic startKey, dynamic endKey}) =>
      _channel.invokeMethod('valuesBetween', {
        'name': name,
        'startKey': startKey,
        'endKey': endKey,
      });

  @override
  Future<Map<dynamic, E>> toMap() =>
      _channel.invokeMethod('toMap', {'name': name});
}

/// Isolated implementation of [LazyBoxBase]
class IsolatedLazyBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedLazyBox<E> {
  /// Constructor
  IsolatedLazyBoxImpl(super._channel, super.connection, super.name, super.lazy);
}
