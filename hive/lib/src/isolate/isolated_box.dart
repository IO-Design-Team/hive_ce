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
  IsolatedBoxBase(
    this._channel,
    IsolateConnection connection,
    this.name,
    this.lazy,
  ) : _eventChannel = IsolateEventChannel('box_$name', connection);

  /// The name of the box
  final String name;

  /// Whether the box is lazy
  final bool lazy;

  /// Whether the box is open
  Future<bool> get isOpen => _channel.invokeMethod('isOpen', {'name': name});

  /// The path of the box
  Future<String?> get path => _channel.invokeMethod('path', {'name': name});

  /// The keys of the box
  Future<Iterable> get keys => _channel.invokeMethod('keys', {'name': name});

  /// The length of the box
  Future<int> get length => _channel.invokeMethod('length', {'name': name});

  /// Whether the box is empty
  Future<bool> get isEmpty => _channel.invokeMethod('isEmpty', {'name': name});

  /// Whether the box is not empty
  Future<bool> get isNotEmpty =>
      _channel.invokeMethod('isNotEmpty', {'name': name});

  /// The key at the given index
  Future keyAt(int index) =>
      _channel.invokeMethod('keyAt', {'name': name, 'index': index});

  /// Watch the box for changes filtered by key
  Stream<BoxEvent> watch({dynamic key}) => _stream ??= _eventChannel
      .receiveBroadcastStream()
      .cast<BoxEvent>()
      .where((event) => key == null || event.key == key);

  /// Whether the box contains the given key
  Future<bool> containsKey(dynamic key) =>
      _channel.invokeMethod('containsKey', {'name': name, 'key': key});

  /// Put a value in the box
  Future<void> put(dynamic key, E value) =>
      _channel.invokeMethod('put', {'name': name, 'key': key, 'value': value});

  /// Put a value at the given index
  Future<void> putAt(int index, E value) => _channel
      .invokeMethod('putAt', {'name': name, 'index': index, 'value': value});

  /// Put all the given entries in the box
  Future<void> putAll(Map<dynamic, E> entries) =>
      _channel.invokeMethod('putAll', {'name': name, 'entries': entries});

  /// Add a value to the box
  Future<int> add(E value) =>
      _channel.invokeMethod('add', {'name': name, 'value': value});

  /// Add all the given values to the box
  Future<Iterable<int>> addAll(Iterable<E> values) =>
      _channel.invokeMethod('addAll', {'name': name, 'values': values});

  /// Delete a value from the box
  Future<void> delete(dynamic key) =>
      _channel.invokeMethod('delete', {'name': name, 'key': key});

  /// Delete a value at the given index
  Future<void> deleteAt(int index) =>
      _channel.invokeMethod('deleteAt', {'name': name, 'index': index});

  /// Delete all the given values from the box
  Future<void> deleteAll(Iterable keys) =>
      _channel.invokeMethod('deleteAll', {'name': name, 'keys': keys});

  /// Compact the box
  Future<void> compact() => _channel.invokeMethod('compact', {'name': name});

  /// Clear the box
  Future<int> clear() => _channel.invokeMethod('clear', {'name': name});

  /// Close the box
  Future<void> close() => _channel.invokeMethod('close', {'name': name});

  /// Delete the box from the disk
  Future<void> deleteFromDisk() =>
      _channel.invokeMethod('deleteFromDisk', {'name': name});

  /// Flush the box
  Future<void> flush() => _channel.invokeMethod('flush', {'name': name});

  /// Get a value from the box
  Future<E?> get(dynamic key, {E? defaultValue}) =>
      _channel.invokeMethod('get', {
        'name': name,
        'key': key,
        'defaultValue': defaultValue,
      });

  /// Get a value at the given index
  Future<E?> getAt(int index) =>
      _channel.invokeMethod('getAt', {'name': name, 'index': index});
}

/// Isolated implementation of [LazyBoxBase]
class IsolatedLazyBox<E> extends IsolatedBoxBase<E> {
  /// Constructor
  IsolatedLazyBox(super._channel, super.connection, super.name, super.lazy);
}

/// Isolated implementation of [Box]
class IsolatedBox<E> extends IsolatedBoxBase<E> {
  /// Constructor
  IsolatedBox(super._channel, super.connection, super.name, super.lazy);

  /// The values of the box
  Future<List<E>> get values =>
      _channel.invokeMethod('values', {'name': name});

  /// The values of the box between the given keys
  Future<List<E>> valuesBetween({dynamic startKey, dynamic endKey}) =>
      _channel.invokeMethod('valuesBetween', {
        'name': name,
        'startKey': startKey,
        'endKey': endKey,
      });

  /// Convert the box to a map
  Future<Map<dynamic, E>> toMap() =>
      _channel.invokeMethod('toMap', {'name': name});
}
