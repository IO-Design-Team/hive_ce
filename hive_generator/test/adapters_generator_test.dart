import 'package:hive_ce_generator/src/adapters_generator.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

const directives = '''
import 'package:hive_ce/hive.dart';
part 'hive_adapters.g.dart';''';

const personSchema = '''
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
''';

void main() {
  group('adapters_generator', () {
    test('fresh', () {
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
          'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([AdapterSpec<Person>()])
class Person {
  const Person({required this.name, required this.age});

  final String name;
  final int age;
}
''',
        },
        output: {
          'lib/hive/hive_adapters.g.yaml': personSchema,
        },
      );
    });

    test('add type', () {
      // Adding Person2 should result in Person2 having a typeId of 1 no matter
      // the order in the annotation
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
          'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([AdapterSpec<Person2>(), AdapterSpec<Person>()])
class Person {
  const Person({required this.name, required this.age});

  final String name;
  final int age;
}

class Person2 {
  const Person2({required this.name, required this.age});

  final String name;
  final int age;
}
''',
          'lib/hive/hive_adapters.g.yaml': personSchema,
        },
        output: {
          'lib/hive/hive_adapters.g.yaml': '''
$schemaComment
nextTypeId: 2
types:
  Person:
    typeId: 0
    nextIndex: 2
    fields:
      name:
        index: 0
      age:
        index: 1
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

    test('add and remove type', () {
      // Adding Person2 while removing Person should result in Person2 having a
      // typeId of 1
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
          'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([AdapterSpec<Person2>()])
class Person2 {
  const Person2({required this.name, required this.age});

  final String name;
  final int age;
}
''',
          'lib/hive/hive_adapters.g.yaml': personSchema,
        },
        output: {
          'lib/hive/hive_adapters.g.yaml': '''
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

    test('add field', () {
      // A new field on Person should have the last index no matter the order
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
          'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([AdapterSpec<Person>()])
class Person {
  const Person({required this.balance, required this.name, required this.age});

  final double balance;
  final String name;
  final int age;
}
''',
          'lib/hive/hive_adapters.g.yaml': personSchema,
        },
        output: {
          'lib/hive/hive_adapters.g.yaml': '''
$schemaComment
nextTypeId: 1
types:
  Person:
    typeId: 0
    nextIndex: 3
    fields:
      name:
        index: 0
      age:
        index: 1
      balance:
        index: 2
''',
        },
      );
    });

    test('add and remove field', () {
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
          'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([AdapterSpec<Person>()])
class Person {
  const Person({required this.name, required this.balance});

  final String name;
  final double balance;
}
''',
          'lib/hive/hive_adapters.g.yaml': personSchema,
        },
        output: {
          'lib/hive/hive_adapters.g.yaml': '''
$schemaComment
nextTypeId: 1
types:
  Person:
    typeId: 0
    nextIndex: 3
    fields:
      name:
        index: 0
      balance:
        index: 2
''',
        },
      );
    });

    group('validates schema', () {
      test('with invalid next type ID', () {
        expectGeneration(
          input: {
            'pubspec.yaml': pubspec,
            'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([])
void _() {}
''',
            'lib/hive/hive_adapters.g.yaml': '''
nextTypeId: 0
types:
  Person:
    typeId: 0
    nextIndex: 0
    fields: {}
''',
          },
          throws: 'Invalid schema: Next type ID is invalid',
        );
      });

      test('with invalid next field index', () {
        expectGeneration(
          input: {
            'pubspec.yaml': pubspec,
            'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([])
void _() {}
''',
            'lib/hive/hive_adapters.g.yaml': '''
nextTypeId: 1
types:
  Person:
    typeId: 0
    nextIndex: 0
    fields:
      name:
        index: 0
''',
          },
          throws: 'Invalid schema: Next index is invalid for type ID 0',
        );
      });

      test('with duplicate type ID', () {
        expectGeneration(
          input: {
            'pubspec.yaml': pubspec,
            'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([])
void _() {}
''',
            'lib/hive/hive_adapters.g.yaml': '''
nextTypeId: 1
types:
  Person:
    typeId: 0
    nextIndex: 0
    fields: {}
  Person2:
    typeId: 0
    nextIndex: 0
    fields: {}
''',
          },
          throws: 'Invalid schema: Duplicate type ID 0',
        );
      });

      test('with duplicate field index', () {
        expectGeneration(
          input: {
            'pubspec.yaml': pubspec,
            'lib/hive/hive_adapters.dart': '''
$directives

@GenerateAdapters([])
void _() {}
''',
            'lib/hive/hive_adapters.g.yaml': '''
nextTypeId: 1
types:
  Person:
    typeId: 0
    nextIndex: 0
    fields:
      name:
        index: 0
      age:
        index: 0
''',
          },
          throws: 'Invalid schema: Duplicate field index 0 for type ID 0',
        );
      });
    });
  });
}
