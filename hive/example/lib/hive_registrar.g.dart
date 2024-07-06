import 'package:hive_ce/hive.dart';
import 'package:example/main.dart';

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(PersonAdapter());
  }
}
