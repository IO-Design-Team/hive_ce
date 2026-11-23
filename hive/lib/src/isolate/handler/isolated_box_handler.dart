import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/connect/inspectable_box.dart';
import 'package:hive_ce/src/isolate/isolated_box_impl/isolated_box_impl_vm.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:meta/meta.dart';

/// Class to handle method calls to the isolated box
@immutable
class IsolatedBoxHandler extends IsolateStreamHandler {
  /// The wrapped box
  final BoxBase box;

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
        .map((e) => {'key': e.key, 'value': e.value, 'deleted': e.deleted})
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

  static dynamic _unwrapValue(dynamic value) {
    if (value is TransferableTypedData) {
      return value.materialize().asUint8List();
    }
    return value;
  }

  static Uint8List _unwrapBytes(dynamic value) {
    if (value is TransferableTypedData) {
      return value.materialize().asUint8List();
    }
    return value as Uint8List;
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
          _unwrapValue(call.arguments['value']),
        );
      case 'putAt':
        await box.putAt(
          call.arguments['index'],
          _unwrapValue(call.arguments['value']),
        );
      case 'putAll':
        final packedBytes = call.arguments['packedBytes'];
        if (packedBytes != null) {
          final keys = call.arguments['keys'] as List;
          final lengths = call.arguments['lengths'] as Int32List;
          final packed = _unwrapBytes(packedBytes);
          final entries = <dynamic, Uint8List>{};
          var offset = 0;
          for (var i = 0; i < keys.length; i++) {
            final len = lengths[i];
            entries[keys[i]] =
                Uint8List.sublistView(packed, offset, offset + len);
            offset += len;
          }
          await box.putAll(entries);
        } else {
          await box.putAll(call.arguments['entries']);
        }
      case 'add':
        return await box.add(_unwrapValue(call.arguments['value']));
      case 'addAll':
        final packedBytes = call.arguments['packedBytes'];
        final Iterable<int> keys;
        if (packedBytes != null) {
          final lengths = call.arguments['lengths'] as Int32List;
          final packed = _unwrapBytes(packedBytes);
          var offset = 0;
          final values = List<Uint8List>.generate(
            lengths.length,
            (i) {
              final len = lengths[i];
              final slice = Uint8List.sublistView(packed, offset, offset + len);
              offset += len;
              return slice;
            },
            growable: false,
          );
          keys = await box.addAll(values);
        } else {
          keys = await box.addAll(call.arguments['values']);
        }
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
        // This needs to be a list or it is unsendable
        return (box as Box).values.toList();
      case 'valuesBetween':
        // This needs to be a list or it is unsendable
        return (box as Box)
            .valuesBetween(
              startKey: call.arguments['startKey'],
              endKey: call.arguments['endKey'],
            )
            .toList();
      case 'get':
        if (box.lazy) {
          return await (box as LazyBox).get(
            call.arguments['key'],
            defaultValue: IsolatedBoxBaseImpl.defaultValuePlaceholder,
          );
        } else {
          return (box as Box).get(
            call.arguments['key'],
            defaultValue: IsolatedBoxBaseImpl.defaultValuePlaceholder,
          );
        }
      case 'getAt':
        if (box.lazy) {
          return await (box as LazyBox).getAt(call.arguments['index']);
        } else {
          return (box as Box).getAt(call.arguments['index']);
        }
      case 'toMap':
        return (box as Box).toMap();
      case 'getFrames':
        final frames = await (box as InspectableBox).getFrames();
        return frames.map((e) => e.toJson()).toList();
      default:
        return call.notImplemented();
    }
  }
}
