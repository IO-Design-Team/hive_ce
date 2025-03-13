import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// Class to handle method calls to the isolated box
class IsolatedBoxHandler extends IsolateStreamHandler {
  /// The wrapped box
  final BoxBase box;
  StreamSubscription? _subscription;

  /// Constructor
  IsolatedBoxHandler(this.box, IsolateConnection connection) {
    IsolateEventChannel('box_${box.name}', connection).setStreamHandler(this);
  }

  @override
  void onListen(dynamic arguments, IsolateEventSink events) {
    if (_subscription != null) return;

    final subscription = _subscription = box.watch().listen(events.success);
    subscription.onError(
      (e) => events.error(
        code: 'box_watch_error',
        message: 'Error watching ${box.name}',
        details: e,
      ),
    );
    subscription.onDone(events.endOfStream);
  }

  @override
  void onCancel(dynamic arguments) {
    // Don't need to do anything
  }

  void _close() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// The method call handler for the box
  Future<dynamic> call(IsolateMethodCall call) async {
    switch (call.method) {
      case 'isOpen':
        return box.isOpen;
      case 'path':
        return box.path;
      case 'keys':
        return box.keys;
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
        await box.put(call.arguments['key'], call.arguments['value']);
      case 'putAt':
        await box.putAt(call.arguments['index'], call.arguments['value']);
      case 'putAll':
        await box.putAll(call.arguments['entries']);
      case 'add':
        return box.add(call.arguments['value']);
      case 'addAll':
        return box.addAll(call.arguments['values']);
      case 'delete':
        await box.delete(call.arguments['key']);
      case 'deleteAt':
        await box.deleteAt(call.arguments['index']);
      case 'deleteAll':
        await box.deleteAll(call.arguments['keys']);
      case 'compact':
        await box.compact();
      case 'clear':
        return box.clear();
      case 'close':
        await box.close();
        _close();
      case 'deleteFromDisk':
        await box.deleteFromDisk();
        _close();
      case 'flush':
        await box.flush();
      case 'values':
        return (box as Box).values;
      case 'valuesBetween':
        return (box as Box).valuesBetween(
          startKey: call.arguments['startKey'],
          endKey: call.arguments['endKey'],
        );
      case 'get':
        if (box.lazy) {
          return (box as LazyBox).get(call.arguments['key']);
        } else {
          return (box as Box).get(call.arguments['key']);
        }
      case 'getAt':
        if (box.lazy) {
          return (box as LazyBox).getAt(call.arguments['index']);
        } else {
          return (box as Box).getAt(call.arguments['index']);
        }
      case 'toMap':
        return (box as Box).toMap();
      default:
        return IsolateException.notImplemented(call.method);
    }
  }
}
