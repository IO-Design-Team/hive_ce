import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';

class IsolatedBoxHandler extends IsolateStreamHandler {
  final BoxBase box;
  final IsolateEventChannel _channel;
  final _watchers = <String, ({StreamSubscription subscription, int count})>{};

  /// Constructor
  IsolatedBoxHandler(this.box, IsolateConnection connection)
      : _channel = IsolateEventChannel('box_${box.name}', connection) {
    _channel.setStreamHandler(this);
  }

  @override
  void onListen(dynamic key, IsolateEventSink events) {
    _watchers.update(
      key,
      (e) => (subscription: e.subscription, count: e.count + 1),
      ifAbsent: () {
        final subscription = box.watch(key: key).listen(events.success);
        subscription.onError(
          (e) => events.error(
            code: 'box_watch_error',
            message: 'Error watching ${box.name}[$key]',
            details: e,
          ),
        );
        subscription.onDone(events.endOfStream);
        return (subscription: subscription, count: 1);
      },
    );
  }

  @override
  void onCancel(dynamic key) {
    final existing = _watchers[key];
    if (existing == null) return;

    if (existing.count == 1) {
      existing.subscription.cancel();
      _watchers.remove(key);
    } else {
      _watchers.update(
        key,
        (e) => (subscription: e.subscription, count: e.count - 1),
      );
    }
  }

  Future<dynamic> call(IsolateMethodCall call) async {
    switch (call.method) {
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
        await box.clear();
      case 'close':
        await box.close();
      case 'deleteFromDisk':
        await box.deleteFromDisk();
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
