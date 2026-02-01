import 'package:built_collection/built_collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:meta/meta.dart';

@GenerateAdapters([
  AdapterSpec<ClassSpec1>(),
  AdapterSpec<ClassSpec2>(),
  AdapterSpec<ClassSpec3>(),
  AdapterSpec<ClassSpec4>(),
  AdapterSpec<EnumSpec>(),
], firstTypeId: 50)
part 'hive_adapters.g.dart';

@immutable
class ClassSpec1 {
  final int value;
  final int value2;

  const ClassSpec1(this.value, this.value2);
}

@immutable
class ClassSpec2 {
  final String value;
  final String value2;
  final Iterable<String> iterable;
  final Set<String> set;
  final List<String> list;

  final IList<String> iList;
  final ISet<String> iSet;
  final IMap<String, String> iMap;
  final BuiltMap<String, BuiltMap<String, String>> iListList;

  final BuiltList<String> builtList;
  final BuiltSet<String> builtSet;
  final BuiltMap<String, String> builtMap;

  const ClassSpec2(
    this.value,
    this.value2,
    this.iterable,
    this.set,
    this.list,
    this.iList,
    this.iSet,
    this.iMap,
    this.iListList,
    this.builtList,
    this.builtSet,
    this.builtMap,
  );
}

class ClassSpec3 {
  int? value;
}

class ClassSpec4<T extends Object> {}

enum EnumSpec {
  value1,
  value2;

  EnumSpec get getter => EnumSpec.value2;
}
