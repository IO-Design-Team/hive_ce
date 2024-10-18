import 'package:hive_ce/hive.dart';
import 'package:example/hive/hive_adapters.dart';
import 'package:example/named_import.dart';
import 'package:example/types.dart';

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(Class1Adapter());
    registerAdapter(Class2Adapter());
    registerAdapter(ClassSpec1Adapter());
    registerAdapter(ClassSpec2Adapter());
    registerAdapter(ConstructorDefaultsAdapter());
    registerAdapter(EmptyClassAdapter());
    registerAdapter(Enum1Adapter());
    registerAdapter(IterableClassAdapter());
    registerAdapter(NamedImportTypeAdapter());
    registerAdapter(NamedImportsAdapter());
    registerAdapter(NullableTypesAdapter());
  }
}
