import 'package:hive_ce/hive.dart';
import 'package:example/named_import.dart' as named;
import 'package:meta/meta.dart';

part 'types.g.dart';

@HiveType(typeId: 1)
@immutable
class Class1 {
  const Class1(this.nested, [this.enum1]);

  @HiveField(
    0,
    defaultValue: Class2(4, 'param', <int, Map<String, List<Class1>>>{
      5: <String, List<Class1>>{
        'magic': <Class1>[
          Class1(Class2(5, 'sad')),
          Class1(Class2(5, 'sad'), Enum1.emumValue1),
        ],
      },
      67: <String, List<Class1>>{
        'hold': <Class1>[Class1(Class2(42, 'meaning of life'))],
      },
    }),
  )
  final Class2 nested;

  final Enum1? enum1;
}

@HiveType(typeId: 2)
@immutable
class Class2 {
  const Class2(this.param1, this.param2, [this.what]);

  @HiveField(0, defaultValue: 0)
  final int param1;

  @HiveField(1)
  final String param2;

  @HiveField(6)
  final Map<int, Map<String, List<Class1>>>? what;
}

@HiveType(typeId: 3)
enum Enum1 {
  @HiveField(0)
  emumValue1,

  @HiveField(1, defaultValue: true)
  emumValue2,

  @HiveField(2)
  emumValue3,
}

@HiveType(typeId: 4)
class EmptyClass {
  EmptyClass();
}

@HiveType(typeId: 5)
@immutable
class IterableClass {
  const IterableClass(this.list, this.set, this.nestedList, this.nestedSet);

  @HiveField(0)
  final List<String> list;

  @HiveField(1)
  final Set<String> set;

  @HiveField(2)
  final List<Set<String>> nestedList;

  @HiveField(3)
  final Set<List<String>> nestedSet;
}

@HiveType(typeId: 6)
@immutable
class ConstructorDefaults {
  ConstructorDefaults({this.a = 42, this.b = '42', this.c = true, DateTime? d})
    : d = d ?? DateTime.timestamp();

  @HiveField(0)
  final int a;

  @HiveField(1, defaultValue: '6 * 7')
  final String b;

  @HiveField(2)
  final bool c;

  @HiveField(3)
  final DateTime d;
}

@HiveType(typeId: 7)
@immutable
class NullableTypes {
  const NullableTypes({this.a, this.b, this.c});

  @HiveField(0)
  final int? a;

  @HiveField(1)
  final String? b;

  @HiveField(2)
  final bool? c;
}

@HiveType(typeId: 8)
@immutable
class NamedImports {
  const NamedImports(
    this.namedImportType,
    this.namedImportTypeList,
    this.namedImportTypeNullable,
    this.namedImportTypeMap,
  );

  @HiveField(0)
  final named.NamedImportType namedImportType;

  @HiveField(1)
  final List<named.NamedImportType> namedImportTypeList;

  @HiveField(2)
  final named.NamedImportType? namedImportTypeNullable;

  @HiveField(3)
  final Map<named.NamedImportType, named.NamedImportType> namedImportTypeMap;
}
