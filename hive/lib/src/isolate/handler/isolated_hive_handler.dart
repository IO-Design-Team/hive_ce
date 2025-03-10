import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/box/default_compaction_strategy.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/isolate/handler/isolated_box_handler.dart';
import 'package:isolate_channel/isolate_channel.dart';

Future<dynamic> handleHiveMethodCall(
  IsolateMethodCall call,
  IsolateConnection connection,
  Map<String, IsolatedBoxHandler> boxHandlers,
) async {
  switch (call.method) {
    case 'init':
      Hive.init(call.arguments);
    case 'openBox':
      final name = call.arguments['name'];
      final box = await Hive.openBox(
        name,
        encryptionCipher: call.arguments['encryptionCipher'],
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
      final box = await Hive.openLazyBox(
        name,
        encryptionCipher: call.arguments['encryptionCipher'],
        keyComparator: call.arguments['keyComparator'] ?? defaultKeyComparator,
        compactionStrategy:
            call.arguments['compactionStrategy'] ?? defaultCompactionStrategy,
        crashRecovery: call.arguments['crashRecovery'],
        path: call.arguments['path'],
        collection: call.arguments['collection'],
      );
      boxHandlers[name] = IsolatedBoxHandler(box, connection);
    case 'isBoxOpen':
      return Hive.isBoxOpen(call.arguments);
    case 'close':
      await Hive.close();
    case 'deleteBoxFromDisk':
      await Hive.deleteBoxFromDisk(
        call.arguments['name'],
        path: call.arguments['path'],
      );
    case 'deleteFromDisk':
      await Hive.deleteFromDisk();
    case 'boxExists':
      return Hive.boxExists(
        call.arguments['name'],
        path: call.arguments['path'],
      );
    case 'registerAdapter':
      Hive.registerAdapter(
        call.arguments['adapter'],
        internal: call.arguments['internal'],
        override: call.arguments['override'],
      );
    case 'isAdapterRegistered':
      return Hive.isAdapterRegistered(call.arguments);
    case 'resetAdapters':
      // This is a proxy
      // ignore: invalid_use_of_visible_for_testing_member
      Hive.resetAdapters();
    case 'ignoreTypeId':
      Hive.ignoreTypeId(call.arguments);
    default:
      return IsolateException.notImplemented(call.method);
  }
}
