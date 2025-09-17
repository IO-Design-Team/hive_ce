import 'package:hive_ce_inspector/model/hive_internal.dart';

/// Built in schema types
const baseSchema = <String, HiveSchemaType>{
  'Color': HiveSchemaType(
    typeId: 200,
    nextIndex: 5,
    fields: {
      'a': HiveSchemaField(index: 0),
      'r': HiveSchemaField(index: 1),
      'g': HiveSchemaField(index: 2),
      'b': HiveSchemaField(index: 3),
      'colorSpace': HiveSchemaField(index: 4),
    },
  ),
};
