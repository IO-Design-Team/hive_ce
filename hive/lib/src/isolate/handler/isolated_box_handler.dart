import 'package:hive_ce/hive.dart';
import 'package:isolate_channel/isolate_channel.dart';

Future<dynamic> handleBoxMethodCall(IsolateMethodCall call) async {
  final name = call.arguments['name'];
  final lazy = call.arguments['lazy'];
  final box = lazy ? Hive.lazyBox(name) : Hive.box(name);

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
    case 'watch':
    case 'containsKey':
      return box.containsKey(call.arguments['key']);
    case 'put':
      await box.put(call.arguments['key'], call.arguments['value']);
    case 'putAt':
      await box.putAt(call.arguments['index'], call.arguments['value']);
    case 'putAll':
      await box.putAll(call.arguments['entries']);
    case 'add':
      return await box.add(call.arguments['value']);
    case 'addAll':
      return await box.addAll(call.arguments['values']);
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
      if (lazy) {
        return await (box as LazyBox).get(call.arguments['key']);
      } else {
        return (box as Box).get(call.arguments['key']);
      }
    case 'getAt':
      if (lazy) {
        return await (box as LazyBox).getAt(call.arguments['index']);
      } else {
        return (box as Box).getAt(call.arguments['index']);
      }
    case 'toMap':
      return (box as Box).toMap();
    default:
      return IsolateException.notImplemented(call.method);
  }
}
