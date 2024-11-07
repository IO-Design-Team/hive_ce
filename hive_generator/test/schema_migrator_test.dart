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
          ...pubspec,
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
          ...pubspec,
          ...buildYaml,
          ...adapters,
        },
        output: {
          'lib/hive_schema.g.yaml': '''
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
          ...pubspec,
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
          ...pubspec,
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
        throws: SchemaMigratorBuilder.hasNoSetter(
          className: 'Class',
          fieldName: '_value',
        ),
      );
    });

    test('throws with no public getter', () {
      expectGeneration(
        input: {
          ...pubspec,
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
        throws: SchemaMigratorBuilder.hasNoGetter(
          className: 'Class',
          fieldName: '_value',
        ),
      );
    });
  });
}
