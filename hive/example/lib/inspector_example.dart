import 'dart:io';

import 'package:hive_ce/hive.dart';

void main() async {
  final path = Directory.current.path;
  Hive.init(path);

  final box = await Hive.openBox('testBox');
  box.inspect();

  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    await box.add('dave');
  }
}
