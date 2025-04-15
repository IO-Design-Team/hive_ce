import 'package:hive_ce/hive.dart';

@GenerateAdapters(
  [
    AdapterSpec<ClassSpec1>(),
    AdapterSpec<ClassSpec2>(),
    AdapterSpec<EnumSpec>(),
  ],
  firstTypeId: 50,
)
part 'hive_adapters.g.dart';

class ClassSpec1 {
  final int value;
  final int value2;

  ClassSpec1(this.value, this.value2);
}

class ClassSpec2 {
  final String value;
  final String value2;
  final Iterable<String> iterable;
  final Set<String> set;
  final List<String> list;

  ClassSpec2(this.value, this.value2, this.iterable, this.set, this.list);
}

enum EnumSpec {
  value1,
  value2;

  EnumSpec get getter => EnumSpec.value2;
}
