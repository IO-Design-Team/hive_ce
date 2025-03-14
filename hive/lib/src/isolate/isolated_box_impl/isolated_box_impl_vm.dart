import 'dart:async';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
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
  Future<List> get keys => _channel.invokeMethod('keys', {'name': name});

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
      .map(
        (event) => BoxEvent(
            event['key'], _readValue(event['value']), event['deleted']),
      )
      .where((event) => key == null || event.key == key);

  @override
  Future<bool> containsKey(dynamic key) =>
      _channel.invokeMethod('containsKey', {'name': name, 'key': key});

  @override
  Future<void> put(dynamic key, E value) => _channel.invokeMethod(
        'put',
        {'name': name, 'key': key, 'value': _writeValue(value)},
      );

  @override
  Future<void> putAt(int index, E value) => _channel.invokeMethod(
        'putAt',
        {'name': name, 'index': index, 'value': _writeValue(value)},
      );

  @override
  Future<void> putAll(Map<dynamic, E> entries) => _channel.invokeMethod(
        'putAll',
        {
          'name': name,
          'entries':
              entries.map((key, value) => MapEntry(key, _writeValue(value))),
        },
      );

  @override
  Future<int> add(E value) =>
      _channel.invokeMethod('add', {'name': name, 'value': _writeValue(value)});

  @override
  Future<List<int>> addAll(Iterable<E> values) => _channel.invokeMethod(
        'addAll',
        {'name': name, 'values': values.map(_writeValue).toList()},
      );

  @override
  Future<void> delete(dynamic key) =>
      _channel.invokeMethod('delete', {'name': name, 'key': key});

  @override
  Future<void> deleteAt(int index) =>
      _channel.invokeMethod('deleteAt', {'name': name, 'index': index});

  @override
  Future<void> deleteAll(Iterable keys) =>
      _channel.invokeMethod('deleteAll', {'name': name, 'keys': keys.toList()});

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
  Future<E?> get(dynamic key, {E? defaultValue}) async {
    final bytes =
        await _channel.invokeMethod('get', {'name': name, 'key': key});
    if (bytes == null) return defaultValue;
    return _readValue(bytes);
  }

  @override
  Future<E?> getAt(int index) async {
    final bytes =
        await _channel.invokeMethod('getAt', {'name': name, 'index': index});
    if (bytes == null) return null;
    return _readValue(bytes);
  }

  Uint8List _writeValue(E value) {
    final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl);
    writer.write(value);
    return writer.toBytes();
  }

  E? _readValue(Uint8List bytes) {
    final reader = BinaryReaderImpl(bytes, TypeRegistryImpl.nullImpl);
    return reader.read() as E?;
  }
}

/// Isolated implementation of [Box]
class IsolatedBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedBox<E> {
  /// Constructor
  IsolatedBoxImpl(super._channel, super.connection, super.name, super.lazy);

  @override
  Future<Iterable<E>> get values async {
    final bytes = await _channel.invokeMethod('values', {'name': name});
    return bytes.cast<Uint8List>().map(_readValue).cast<E>();
  }

  @override
  Future<Iterable<E>> valuesBetween({dynamic startKey, dynamic endKey}) async {
    final bytes = await _channel.invokeMethod('valuesBetween', {
      'name': name,
      'startKey': startKey,
      'endKey': endKey,
    });
    return bytes.cast<Uint8List>().map(_readValue).cast<E>();
  }

  @override
  Future<Map<dynamic, E>> toMap() async {
    final bytes = await _channel.invokeMethod('toMap', {'name': name});
    return bytes.map((key, value) => MapEntry(key, _readValue(value)));
  }
}

/// Isolated implementation of [LazyBoxBase]
class IsolatedLazyBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedLazyBox<E> {
  /// Constructor
  IsolatedLazyBoxImpl(super._channel, super.connection, super.name, super.lazy);
}
