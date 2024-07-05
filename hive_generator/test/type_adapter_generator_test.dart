import 'package:hive_ce_generator/src/helper.dart';
import 'package:test/test.dart';

void main() {
  group('generateName', () {
    test('.generateName()', () {
      expect(generateAdapterName(r'_$User'), 'UserAdapter');
      expect(
        generateAdapterName(r'_$_SomeClass'),
        'SomeClassAdapter',
      );
    });
  });
}
