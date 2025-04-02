import 'dart:isolate';

import 'package:hive_ce/src/isolate/handler/isolated_box_handler.dart';
import 'package:hive_ce/src/isolate/handler/isolated_hive_handler.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// The entry point for the Hive isolate
void isolateEntryPoint(SendPort send) {
  final connection = setupIsolate(send);

  final hiveChannel = IsolateMethodChannel('hive', connection);
  final boxChannel = IsolateMethodChannel('box', connection);

  final boxHandlers = <String, IsolatedBoxHandler>{};

  hiveChannel.setMethodCallHandler(
    (call) => handleHiveMethodCall(call, connection, boxHandlers),
  );
  boxChannel.setMethodCallHandler((call) {
    final name = call.arguments['name'];
    final handler = boxHandlers[name];
    if (handler == null) {
      return IsolateException(
        code: 'no_box_handler',
        message: 'No box handler found for box: $name',
        details: 'Box may have been closed',
      );
    }
    return handler(call);
  });
}
