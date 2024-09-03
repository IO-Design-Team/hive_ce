import 'package:hive_ce/hive.dart';
import 'package:example/types.dart';

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(Class1Adapter());
    registerAdapter(Class2Adapter());
    registerAdapter(EmptyClassAdapter());
    registerAdapter(IterableClassAdapter());
    registerAdapter(ConstructorDefaultsAdapter());
    registerAdapter(Enum1Adapter());
  }
}
