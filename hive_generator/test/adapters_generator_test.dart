import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('adapters_generator', () {
    test('clean generation', () async {
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
  });
}
