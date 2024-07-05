import 'package:hive_ce/hive.dart';
import 'package:example/types.dart';

extension HiveRegistrar on Hive {
  static void registerAdapters() {
    Hive.registerAdapter(Class1Adapter());
    Hive.registerAdapter(Class2Adapter());
    Hive.registerAdapter(EmptyClassAdapter());
    Hive.registerAdapter(IterableClassAdapter());
    Hive.registerAdapter(Enum1Adapter());
  }
}
