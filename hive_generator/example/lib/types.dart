import 'package:hive_ce/hive.dart';

part 'types.g.dart';

@HiveType(typeId: 1)

/// TODO: Document this!
class Class1 {
  /// TODO: Document this!
  const Class1(this.nested, [this.enum1]);

  @HiveField(
    0,
    defaultValue: Class2(
      4,
      'param',
      <int, Map<String, List<Class1>>>{
        5: <String, List<Class1>>{
          'magic': <Class1>[
            Class1(Class2(5, 'sad')),
            Class1(Class2(5, 'sad'), Enum1.emumValue1),
          ],
        },
        67: <String, List<Class1>>{
          'hold': <Class1>[
            Class1(Class2(42, 'meaning of life')),
          ],
        },
      },
    ),
  )

  /// TODO: Document this!
  final Class2 nested;

  /// TODO: Document this!
  final Enum1? enum1;
}

@HiveType(typeId: 2)

/// TODO: Document this!
class Class2 {
  /// TODO: Document this!
  const Class2(this.param1, this.param2, [this.what]);

  @HiveField(0, defaultValue: 0)

  /// TODO: Document this!
  final int param1;

  @HiveField(1)

  /// TODO: Document this!
  final String param2;

  @HiveField(6)

  /// TODO: Document this!
  final Map<int, Map<String, List<Class1>>>? what;
}

@HiveType(typeId: 3)

/// TODO: Document this!
enum Enum1 {
  @HiveField(0)

  /// TODO: Document this!
  emumValue1,

  @HiveField(1, defaultValue: true)

  /// TODO: Document this!
  emumValue2,

  @HiveField(2)

  /// TODO: Document this!
  emumValue3,
}

@HiveType(typeId: 4)

/// TODO: Document this!
class EmptyClass {
  /// TODO: Document this!
  EmptyClass();
}
