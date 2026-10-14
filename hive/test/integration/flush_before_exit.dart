import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive_ce.dart';

Future<void> main(List<String> args) async {
  Hive.init(args[0]);
  final box = await Hive.openBox<String>('box');
  unawaited(box.put('name', 'David'));
  if (args[1] == 'flush') await Hive.flush();
  exit(0);
}
