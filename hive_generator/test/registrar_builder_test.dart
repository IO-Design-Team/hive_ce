import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('registrar_builder', () {
    test('outputs to lib folder by default', () {
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
          'lib/nested/type.dart': '''
import 'package:hive_ce/hive.dart';
part 'type.g.dart';

@HiveType(typeId: 0)
class Type {}
''',
        },
        output: {
          'lib/hive_registrar.g.dart': fileExists,
        },
      );
    });

    test('does not output with no types', () {
      expectGeneration(
        input: {
          'pubspec.yaml': pubspec,
        },
        output: {
          'lib/hive_registrar.g.dart': fileDoesNotExist,
        },
      );
    });
  });
}
