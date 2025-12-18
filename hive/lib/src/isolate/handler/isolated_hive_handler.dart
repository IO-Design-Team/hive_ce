import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/box/default_compaction_strategy.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/isolate/handler/isolated_box_handler.dart';
import 'package:hive_ce/src/util/logger.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// Method call handler for Hive methods
Future<dynamic> handleHiveMethodCall(
  IsolateMethodCall call,
  IsolateConnection connection,
  Map<String, IsolatedBoxHandler> boxHandlers,
) async {
  switch (call.method) {
    case 'init':
      Hive.init(call.arguments['path']);
      (Hive as HiveImpl).setIsolated();
      final loggerLevel = call.arguments['logger_level'];
      Logger.level = LoggerLevel.values.byName(loggerLevel);
    case 'openBox':
      final name = call.arguments['name'];
      if (boxHandlers.containsKey(name)) {
        // Ensure this is a valid `openBox` call
        Hive.box(name);
        return;
      }

      final box = await Hive.openBox(
        name,
        keyComparator: call.arguments['keyComparator'] ?? defaultKeyComparator,
        compactionStrategy:
            call.arguments['compactionStrategy'] ?? defaultCompactionStrategy,
        crashRecovery: call.arguments['crashRecovery'],
        path: call.arguments['path'],
        bytes: call.arguments['bytes'],
        collection: call.arguments['collection'],
      );
      boxHandlers[name] = IsolatedBoxHandler(box, connection);
    case 'openLazyBox':
      final name = call.arguments['name'];
      if (boxHandlers.containsKey(name)) {
        // Ensure this is a valid `openLazyBox` call
        Hive.lazyBox(name);
        return;
      }

      final box = await Hive.openLazyBox(
        name,
        keyComparator: call.arguments['keyComparator'] ?? defaultKeyComparator,
        compactionStrategy:
            call.arguments['compactionStrategy'] ?? defaultCompactionStrategy,
        crashRecovery: call.arguments['crashRecovery'],
        path: call.arguments['path'],
        collection: call.arguments['collection'],
      );
      boxHandlers[name] = IsolatedBoxHandler(box, connection);
    case 'deleteBoxFromDisk':
      await Hive.deleteBoxFromDisk(
        call.arguments['name'],
        path: call.arguments['path'],
      );
    case 'boxExists':
      return Hive.boxExists(
        call.arguments['name'],
        path: call.arguments['path'],
      );
    case 'unregisterBox':
      boxHandlers.remove(call.arguments['name']);
    default:
      return call.notImplemented();
  }
}
