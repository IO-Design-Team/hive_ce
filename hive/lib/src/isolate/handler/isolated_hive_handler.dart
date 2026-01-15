import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/box/box_base_impl.dart';
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
      final lazy = call.arguments['lazy'];

      if (boxHandlers.containsKey(name)) {
        // Ensure this is a valid `openBox` call
        if (lazy) {
          Hive.lazyBox(name);
        } else {
          Hive.box(name);
        }
        return;
      }

      final keyComparator =
          call.arguments['keyComparator'] ?? defaultKeyComparator;
      final compactionStrategy =
          call.arguments['compactionStrategy'] ?? defaultCompactionStrategy;
      final crashRecovery = call.arguments['crashRecovery'];
      final path = call.arguments['path'];
      final bytes = call.arguments['bytes'];
      final collection = call.arguments['collection'];

      final BoxBase box;
      if (lazy) {
        box = await Hive.openLazyBox(
          name,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
        );
      } else {
        box = await Hive.openBox(
          name,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
          bytes: bytes,
          collection: collection,
        );
      }

      final keyCrc = call.arguments['keyCrc'];
      (box as BoxBaseImpl).keyCrc = keyCrc;

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
