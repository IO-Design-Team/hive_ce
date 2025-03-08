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
  final bool lazy;

  Map<String, dynamic> get _params => {
        'name': name,
        'lazy': lazy,
      };

  bool _open = true;

  bool get isOpen => _open;

  Future<String?> get path => _channel.invokeMethod('path', _params);

  Future<Iterable> get keys => _channel.invokeMethod('keys', _params);

  Future<int> get length => _channel.invokeMethod('length', _params);

  Future<bool> get isEmpty => _channel.invokeMethod('isEmpty', _params);

  Future<bool> get isNotEmpty => _channel.invokeMethod('isNotEmpty', _params);

  Future keyAt(int index) =>
      _channel.invokeMethod('keyAt', {..._params, 'index': index});

  // TODO: Fix this
  Stream<BoxEvent> watch({dynamic key}) => _stream ??= _eventChannel
      .receiveBroadcastStream(key)
      .map((event) => BoxEvent(event['key'], event['value'], event['deleted']));

  Future<bool> containsKey(key) =>
      _channel.invokeMethod('containsKey', {..._params, 'key': key});

  Future<void> put(key, E value) =>
      _channel.invokeMethod('put', {..._params, 'key': key, 'value': value});

  Future<void> putAt(int index, E value) => _channel
      .invokeMethod('putAt', {..._params, 'index': index, 'value': value});

  Future<void> putAll(Map<dynamic, E> entries) =>
      _channel.invokeMethod('putAll', {..._params, 'entries': entries});

  Future<int> add(E value) =>
      _channel.invokeMethod('add', {..._params, 'value': value});

  Future<Iterable<int>> addAll(Iterable<E> values) =>
      _channel.invokeMethod('addAll', {..._params, 'values': values});

  Future<void> delete(key) =>
      _channel.invokeMethod('delete', {..._params, 'key': key});

  Future<void> deleteAt(int index) =>
      _channel.invokeMethod('deleteAt', {..._params, 'index': index});

  Future<void> deleteAll(Iterable keys) =>
      _channel.invokeMethod('deleteAll', {..._params, 'keys': keys});

  Future<void> compact() => _channel.invokeMethod('compact', _params);

  Future<int> clear() => _channel.invokeMethod('clear', _params);

  Future<void> close() async {
    await _channel.invokeMethod('close', _params);
    _open = false;
  }

  Future<void> deleteFromDisk() async {
    await _channel.invokeMethod('deleteFromDisk', _params);
    _open = false;
  }

  Future<void> flush() => _channel.invokeMethod('flush', _params);

  Future<E?> get(key, {E? defaultValue}) => _channel.invokeMethod('get', {
        ..._params,
        'key': key,
        'defaultValue': defaultValue,
      });

  Future<E?> getAt(int index) =>
      _channel.invokeMethod('getAt', {..._params, 'index': index});
}

class IsolatedLazyBox<E> extends IsolatedBoxBase<E> {
  /// Constructor
  IsolatedLazyBox(super._channel, super._eventChannel, super.name, super.lazy);
}

class IsolatedBox<E> extends IsolatedBoxBase<E> {
  /// Constructor
  IsolatedBox(super._channel, super._eventChannel, super.name, super.lazy);

  Future<Iterable<E>> get values => _channel.invokeMethod('values', _params);

  Future<Iterable<E>> valuesBetween({dynamic startKey, dynamic endKey}) =>
      _channel.invokeMethod('valuesBetween', {
        ..._params,
        'startKey': startKey,
        'endKey': endKey,
      });

  Future<Map<dynamic, E>> toMap() => _channel.invokeMethod('toMap', _params);
}
