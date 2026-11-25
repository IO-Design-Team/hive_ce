import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/connect/inspectable_box.dart';
import 'package:hive_ce/src/isolate/isolate_transfer.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

/// Class to handle method calls to the isolated box
@immutable
class IsolatedBoxHandler extends IsolateStreamHandler {
  /// The wrapped box
  final BoxBase<Uint8List> box;

  /// Map of identity hash codes to subscriptions
  final _subscriptions = <int, StreamSubscription>{};

  /// Constructor
  IsolatedBoxHandler(this.box, IsolateConnection connection) {
    IsolateEventChannel('box_${box.name}', connection).setStreamHandler(this);
  }

  @override
  void onListen(dynamic arguments, IsolateEventSink events) {
    final id = arguments as int;
    if (_subscriptions.containsKey(id)) return;

    final subscription = box
        .watch()
        .map(
          (e) => {
            'key': e.key,
            'value': _detachBytes(e.value as Uint8List?),
            'deleted': e.deleted,
          },
        )
        .listen(events.success);
    subscription.onError(
      (e) => events.error(
        code: 'box_watch_error',
        message: 'Error watching ${box.name}',
        details: e,
      ),
    );
    subscription.onDone(events.endOfStream);
    _subscriptions[id] = subscription;
  }

  @override
  void onCancel(dynamic arguments) {
    final id = arguments as int;
    _subscriptions.remove(id)?.cancel();
  }

  // 4 KiB (one page) is well above single-frame overhead (header + key + CRC)
  // and cheap enough for SendPort to copy directly, avoiding an extra copy on
  // small buffers while still detaching views into large box or batch buffers.
  static const _maxSlackBytes = 4096;
  static final _emptyHeader = Uint32List(0);

  // Detach views backed by much larger buffers so SendPort copies only the value.
  static Object? _detachBytes(Uint8List? value) {
    if (value != null &&
        value.buffer.lengthInBytes - value.length > _maxSlackBytes) {
      return wrapBytes(value);
    }
    return value;
  }

  // Pack raw value slices as [count, ...lengths, ...rawValues] in one transfer.
  static TransferableTypedData? _packValues(Iterable<Uint8List> rawValues) {
    final chunks = <TypedData>[_emptyHeader, ...rawValues];
    final count = chunks.length - 1;
    if (count == 0) return null;

    final header = Uint32List(count + 1);
    header[0] = count;
    for (var i = 0; i < count; i++) {
      header[i + 1] = chunks[i + 1].lengthInBytes;
    }
    chunks[0] = header;
    return TransferableTypedData.fromList(chunks);
  }

  static List<Uint8List> _unpackValues(dynamic value) {
    final reader = BinaryReaderImpl(
      unwrapBytes(value),
      TypeRegistryImpl.nullImpl,
    );
    final values = <Uint8List>[];
    while (reader.availableBytes > 0) {
      values.add(reader.viewBytes(reader.readUint32()));
    }
    return values;
  }

  void _close() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// The method call handler for the box
  Future<dynamic> call(IsolateMethodCall call) async {
    switch (call.method) {
      case 'path':
        return box.path;
      case 'keys':
        return box.keys.toList();
      case 'length':
        return box.length;
      case 'isEmpty':
        return box.isEmpty;
      case 'isNotEmpty':
        return box.isNotEmpty;
      case 'keyAt':
        return box.keyAt(call.arguments['index']);
      case 'containsKey':
        return box.containsKey(call.arguments['key']);
      case 'put':
        await box.put(
          call.arguments['key'],
          unwrapBytes(call.arguments['value']),
        );
      case 'putAt':
        await box.putAt(
          call.arguments['index'],
          unwrapBytes(call.arguments['value']),
        );
      case 'putAll':
        await box.putAll(
          Map.fromIterables(
            call.arguments['keys'] as List,
            _unpackValues(call.arguments['values']),
          ),
        );
      case 'add':
        return await box.add(unwrapBytes(call.arguments['value']));
      case 'addAll':
        final keys = await box.addAll(_unpackValues(call.arguments['values']));
        return keys.toList();
      case 'delete':
        await box.delete(call.arguments['key']);
      case 'deleteAt':
        await box.deleteAt(call.arguments['index']);
      case 'deleteAll':
        await box.deleteAll(call.arguments['keys']);
      case 'compact':
        await box.compact();
      case 'clear':
        return await box.clear();
      case 'close':
        await box.close();
        _close();
      case 'deleteFromDisk':
        await box.deleteFromDisk();
        _close();
      case 'flush':
        await box.flush();
      case 'values':
        return _packValues((box as Box<Uint8List>).values);
      case 'valuesBetween':
        return _packValues(
          (box as Box<Uint8List>).valuesBetween(
            startKey: call.arguments['startKey'],
            endKey: call.arguments['endKey'],
          ),
        );
      case 'get':
        if (box.lazy) {
          return await (box as LazyBox<Uint8List>).get(call.arguments['key']);
        } else {
          return _detachBytes(
            (box as Box<Uint8List>).get(call.arguments['key']),
          );
        }
      case 'getAt':
        if (box.lazy) {
          return await (box as LazyBox<Uint8List>)
              .getAt(call.arguments['index']);
        } else {
          return _detachBytes(
            (box as Box<Uint8List>).getAt(call.arguments['index']),
          );
        }
      case 'toMap':
        final eagerBox = box as Box<Uint8List>;
        return {
          'keys': eagerBox.keys.toList(growable: false),
          'values': _packValues(eagerBox.values),
        };
      case 'getFrames':
        final frames = await (box as InspectableBox).getFrames();
        return frames.map((e) => e.toJson()).toList();
      default:
        return call.notImplemented();
    }
  }
}
