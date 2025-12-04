import 'package:hive_ce_generator/src/builder/schema_migrator_builder.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

const buildYaml = {
  'build.yaml': r'''
targets:
  $default:
    builders:
      hive_ce_generator|hive_schema_migrator:
        enabled: true
''',
};

const adapters = {
  'lib/adapters.dart': '''
import 'package:hive_ce/hive.dart';

@HiveType(typeId: 1)
class Class1 {}

@HiveType(typeId: 0)
class Class2 {
  const Class2(this.lastName, this.firstName);

  @HiveField(1)
  final String lastName;

  @HiveField(0)
  final String firstName;
}
''',
  'lib/adapters_2.dart': '''
import 'package:hive_ce/hive.dart';

@HiveType(typeId: 3)
class Class3 {
  Class3({required double value}): _value = value;

  @HiveField(0)
  double _value;

  double get value => _value;
}

@HiveType(typeId: 4)
enum Enum {
  @HiveField(0)
  a,

  @HiveField(1)
  b,

  @HiveField(2)
  c,
}
''',
};

void main() {
  group('schema_migrator', () {
    test('does not run if not enabled', () {
      expectGeneration(
        input: {
          ...pubspec(),
          ...adapters,
        },
        output: {
          'lib/hive_schema.g.yaml': fileDoesNotExist,
        },
      );
    });

    test('generates schema', () {
      expectGeneration(
        input: {
          ...pubspec(),
          ...buildYaml,
          ...adapters,
        },
        output: {
          'lib/hive/hive_adapters.dart': '''
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator_test/adapters.dart';
import 'package:hive_ce_generator_test/adapters_2.dart';

@GenerateAdapters([
  AdapterSpec<Class2>(),
  AdapterSpec<Class1>(),
  AdapterSpec<Class3>(),
  AdapterSpec<Enum>(),
])
part 'hive_adapters.g.dart';
''',
          'lib/hive/hive_adapters.g.yaml': '''
$schemaComment
nextTypeId: 5
types:
  Class2:
    typeId: 0
    nextIndex: 2
    fields:
      firstName:
        index: 0
      lastName:
        index: 1
  Class1:
    typeId: 1
    nextIndex: 0
    fields: {}
  Class3:
    typeId: 3
    nextIndex: 1
    fields:
      value:
        index: 0
  Enum:
    typeId: 4
    nextIndex: 3
    fields:
      a:
        index: 0
      b:
        index: 1
      c:
        index: 2
''',
        },
      );
    });

    test('throws with default value', () {
      expectGeneration(
        input: {
          ...pubspec(),
          ...buildYaml,
          'lib/adapters.dart': '''
import 'package:hive_ce/hive.dart';

@HiveType(typeId: 0)
class Class {
  @HiveField(0, defaultValue: 42)
  int? value;
}
''',
        },
        throws: SchemaMigratorBuilder.hasAnnotationDefaultValue(
          className: 'Class',
          fieldName: 'value',
        ),
      );
    });

    test('throws with no public setter', () {
      expectGeneration(
        input: {
          ...pubspec(),
          ...buildYaml,
          'lib/adapters.dart': '''
import 'package:hive_ce/hive.dart';

@HiveType(typeId: 0)
class Class {
  @HiveField(0)
  int? _value;

  int? get value => _value;
}
''',
        },
        throws: SchemaMigratorBuilder.hasNoPublicSetter(
          className: 'Class',
          fieldName: '_value',
        ),
      );
    });

    test('throws with no public getter', () {
      expectGeneration(
        input: {
          ...pubspec(),
          ...buildYaml,
          'lib/adapters.dart': '''
import 'package:hive_ce/hive.dart';

@HiveType(typeId: 0)
class Class {
  Class({required int value}): _value = value;

  @HiveField(0)
  int? _value;
}
''',
        },
        throws: SchemaMigratorBuilder.hasNoPublicGetter(
          className: 'Class',
          fieldName: '_value',
        ),
      );
    });

    test('throws with schema mismatch', () {
      expectGeneration(
        input: {
          ...pubspec(),
          ...buildYaml,
          'lib/adapters.dart': '''
import 'package:hive_ce/hive.dart';

@HiveType(typeId: 0)
class Class {
  @HiveField(0)
  int? value;

  int? value2;
}
''',
        },
        throws: SchemaMigratorBuilder.hasSchemaMismatch(
          className: 'Class',
          accessors: {'value2'},
        ),
      );
    });

    test(
      'works with freezed classes',
      () {
        expectGeneration(
          input: {
            ...pubspec(
              dependencies: {'freezed_annotation: any'},
              devDependencies: {'freezed: any'},
            ),
            ...buildYaml,
            'lib/adapters.dart': '''
import 'package:hive_ce/hive.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'adapters.freezed.dart';
part 'adapters.g.dart';

@HiveType(typeId: 0)
@freezed
sealed class Class with _\$Class {
  factory Class({@HiveField(0) required int value}) = _Class;
}
''',
          },
          output: {
            'lib/hive/hive_adapters.dart': '''
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_generator_test/adapters.dart';

@GenerateAdapters([
  AdapterSpec<Class>(),
])
part 'hive_adapters.g.dart';
''',
            'lib/hive/hive_adapters.g.yaml': '''
$schemaComment
nextTypeId: 1
types:
  Class:
    typeId: 0
    nextIndex: 1
    fields:
      value:
        index: 0
''',
          },
        );
      },
      skip: 'Waiting on freezed analyzer 9 suport',
    );
  });
}
