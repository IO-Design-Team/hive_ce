import 'dart:convert';

import 'package:hive_ce/src/schema/hive_schema.dart';
import 'package:test/test.dart';

void main() {
  group('Hive schema', () {
    test('JSON', () {
      final schema = HiveSchema(
        nextTypeId: 0,
        types: {
          'Test': HiveSchemaType(
            typeId: 0,
            nextIndex: 0,
            fields: {'test': HiveSchemaField(index: 0)},
          )
        },
      );

      final json = jsonEncode(schema);
      expect(json, isNotEmpty);

      final deserialized = HiveSchema.fromJson(jsonDecode(json));
      expect(deserialized.nextTypeId, schema.nextTypeId);
    });

    test('copyWith', () {
      final type = HiveSchemaType(
        typeId: 0,
        nextIndex: 0,
        fields: {'test': HiveSchemaField(index: 0)},
      );
      expect(type.fields, isNotEmpty);

      final copy = type.copyWith(fields: {});
      expect(copy.fields, isEmpty);
    });
  });
}
