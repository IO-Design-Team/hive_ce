import 'package:hive_ce_generator/src/adapters_generator.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('adapters_generator', () {
    test('clean', () async {
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
          'lib/hive/hive_adapters.dart': '''
import 'package:hive_ce/hive.dart';
part 'hive_adapters.g.dart';

@GenerateAdapters([AdapterSpec<Person>()])
class Person {
  const Person({required this.name, required this.age});

  final String name;
  final int age;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': fileExists,
          'lib/hive/hive_registrar.g.dart': fileExists,
          'lib/hive/hive_schema.yaml': '''
$schemaComment
nextTypeId: 1
types: 
  Person: 
    typeId: 0
    nextIndex: 2
    fields: 
      name: 
        index: 0
      age: 
        index: 1
''',
        },
      );
    });

    test('add type', () async {
      // Adding Person2 while removing Person should result in Person2 having a
      // typeId of 1
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
          'lib/hive/hive_adapters.dart': '''
import 'package:hive_ce/hive.dart';
part 'hive_adapters.g.dart';

@GenerateAdapters([AdapterSpec<Person2>()])
class Person2 {
  const Person2({required this.name, required this.age});

  final String name;
  final int age;
}
''',
          'lib/hive/hive_schema.yaml': '''
nextTypeId: 1
types: 
  Person: 
    typeId: 0
    nextIndex: 2
    fields: 
      name: 
        index: 0
      age: 
        index: 1
''',
        },
        output: {
          'lib/hive/hive_adapters.g.dart': fileExists,
          'lib/hive/hive_registrar.g.dart': fileExists,
          'lib/hive/hive_schema.yaml': '''
$schemaComment
nextTypeId: 2
types: 
  Person2: 
    typeId: 1
    nextIndex: 2
    fields: 
      name: 
        index: 0
      age: 
        index: 1
''',
        },
      );
    });
  });
}
