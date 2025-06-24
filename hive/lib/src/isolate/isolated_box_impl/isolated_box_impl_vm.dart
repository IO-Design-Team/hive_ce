import 'dart:async';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/connect/hive_connect.dart';
import 'package:hive_ce/src/connect/hive_connect_api.dart';
import 'package:hive_ce/src/connect/inspectable_box.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/impl/isolated_hive_impl_vm.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// Isolated implementation of [BoxBase]
///
/// Most methods are async due to isolate communication
abstract class IsolatedBoxBaseImpl<E>
    implements IsolatedBoxBase<E>, InspectableBox {
  /// Value to inform the get method to return the default value
  static const defaultValuePlaceholder = '_hive_ce.defaultValue';

  final IsolatedHiveImpl _hive;
  final HiveCipher? _cipher;
  final IsolateMethodChannel _channel;
  final IsolateEventChannel _eventChannel;
  Stream<BoxEvent>? _stream;

  var _open = true;

  /// Constructor
  IsolatedBoxBaseImpl(
    this._hive,
    this.name,
    this._cipher,
    IsolateConnection connection,
    this._channel,
  ) : _eventChannel = IsolateEventChannel('box_$name', connection);

  /// Not part of public API
  Type get valueType => E;

  @override
  final String name;

  @override
  bool get isOpen => _open;

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
  Stream<BoxEvent> watch({dynamic key}) {
    final stream = _stream ??=
        _eventChannel.receiveBroadcastStream(identityHashCode(this)).map(
              (event) => BoxEvent(
                event['key'],
                _readValue(event['value']),
                event['deleted'],
              ),
            );
    return stream.where((event) => key == null || event.key == key);
  }

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
  Future<void> close() async {
    if (!_open) return;
    await _channel.invokeMethod('close', {'name': name});
    _open = false;
    await _hive.unregisterBox(name);
    HiveConnect.unregisterBox(this);
  }

  @override
  Future<void> deleteFromDisk() async {
    if (!_open) return;
    await _channel.invokeMethod('deleteFromDisk', {'name': name});
    _open = false;
    await _hive.unregisterBox(name);
  }

  @override
  Future<void> flush() => _channel.invokeMethod('flush', {'name': name});

  @override
  Future<E?> get(dynamic key, {E? defaultValue}) async {
    final result =
        await _channel.invokeMethod('get', {'name': name, 'key': key});
    if (result == defaultValuePlaceholder) return defaultValue;
    return _readValue(result);
  }

  @override
  Future<E?> getAt(int index) async {
    final bytes =
        await _channel.invokeMethod('getAt', {'name': name, 'index': index});
    return _readValue(bytes);
  }

  Uint8List _writeValue(E value) {
    final writer = BinaryWriterImpl(_hive);
    if (_cipher != null) {
      writer.writeEncrypted(value, _cipher);
    } else {
      writer.write(value);
    }
    return writer.toBytes();
  }

  E? _readValue(Uint8List? bytes) {
    if (bytes == null) return null;
    final reader = BinaryReaderImpl(bytes, _hive);
    final E? value;
    if (_cipher != null) {
      value = reader.readEncrypted(_cipher);
    } else {
      value = reader.read();
    }
    return value;
  }

  @override
  void inspect() => HiveConnect.registerBox(this);

  @override
  TypeRegistry get typeRegistry => _hive;

  @override
  Future<Iterable<InspectorFrame>> getFrames() async {
    final result =
        await _channel.invokeListMethod<Map>('getFrames', {'name': name});
    return result
        .map((e) => e.cast<String, dynamic>())
        .map(InspectorFrame.fromJson);
  }

  @override
  Future<Object?> getValue(Object key) => get(key);
}

/// Isolated implementation of [Box]
class IsolatedBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedBox<E> {
  /// Constructor
  IsolatedBoxImpl(
    super._registry,
    super.name,
    super._cipher,
    super.connection,
    super._channel,
  );

  @override
  final lazy = false;

  @override
  Future<Iterable<E>> get values async {
    final bytes =
        await _channel.invokeListMethod<Uint8List>('values', {'name': name});
    return bytes.map(_readValue).cast<E>();
  }

  @override
  Future<Iterable<E>> valuesBetween({dynamic startKey, dynamic endKey}) async {
    final bytes = await _channel.invokeListMethod<Uint8List>(
      'valuesBetween',
      {'name': name, 'startKey': startKey, 'endKey': endKey},
    );
    return bytes.map(_readValue).cast<E>();
  }

  @override
  Future<Map<dynamic, E>> toMap() async {
    final bytes = await _channel
        .invokeMapMethod<dynamic, Uint8List>('toMap', {'name': name});
    return bytes.map((key, value) => MapEntry(key, _readValue(value) as E));
  }
}

/// Isolated implementation of [LazyBoxBase]
class IsolatedLazyBoxImpl<E> extends IsolatedBoxBaseImpl<E>
    implements IsolatedLazyBox<E> {
  /// Constructor
  IsolatedLazyBoxImpl(
    super._registry,
    super.name,
    super._cipher,
    super.connection,
    super._channel,
  );

  @override
  final lazy = true;
}
