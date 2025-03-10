import 'dart:isolate';

import 'package:hive_ce/src/isolate/handler/isolated_box_handler.dart';
import 'package:hive_ce/src/isolate/handler/isolated_hive_handler.dart';
import 'package:isolate_channel/isolate_channel.dart';

void isolateEntryPoint(SendPort send) {
  final connection = setupIsolate(send);
  final hiveChannel = IsolateMethodChannel('hive', connection);
  final boxChannel = IsolateMethodChannel('box', connection);

  hiveChannel.setMethodCallHandler(handleHiveMethodCall);
  boxChannel.setMethodCallHandler(handleBoxMethodCall);
}
