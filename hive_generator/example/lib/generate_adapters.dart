import 'package:hive_ce/hive.dart';

part 'generate_adapters.g.dart';

@GenerateAdapters([
  AdapterSpec<ClassSpec1>(),
])
_() {}

class ClassSpec1 {
  final int value;

  ClassSpec1(this.value);
}
