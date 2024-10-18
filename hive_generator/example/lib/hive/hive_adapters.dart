import 'package:hive_ce/hive.dart';

part 'hive_adapters.hive.dart';

@GenerateAdapters([
  AdapterSpec<ClassSpec2>(),
  AdapterSpec<ClassSpec1>(),
])
_() {}

class ClassSpec1 {
  final int value;

  ClassSpec1(this.value);
}

class ClassSpec2 {
  final String value;

  ClassSpec2(this.value);
}