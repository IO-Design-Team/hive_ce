import 'package:hive_ce/hive.dart';
import 'package:example/types.dart';

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(Class1Adapter());
    registerAdapter(Class2Adapter());
    registerAdapter(ConstructorDefaultsAdapter());
    registerAdapter(EmptyClassAdapter());
    registerAdapter(Enum1Adapter());
    registerAdapter(IterableClassAdapter());
    registerAdapter(NullableTypesAdapter());
  }
}
