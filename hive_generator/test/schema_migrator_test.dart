import 'package:test/test.dart';

import 'test_utils.dart';

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
class Class3 {}
''',
};

void main() {
  group('schema_migrator', () {
    test('does nothing if not enabled', () {
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
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
          'pubspec.yaml': pubspec,
          'build.yaml': r'''
targets:
  $default:
    builders:
      hive_ce_generator|hive_schema_migrator:
        enabled: true
''',
          ...adapters,
        },
        output: {
          'lib/hive_schema.g.yaml': '''
$schemaComment
nextTypeId: 4
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
    nextIndex: 0
    fields: {}
''',
        },
      );
    });
  });
}
