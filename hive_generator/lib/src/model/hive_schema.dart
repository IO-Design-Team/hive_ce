import 'package:json_annotation/json_annotation.dart';

part 'hive_schema.g.dart';

@JsonSerializable()
class HiveSchema {
  final int nextTypeId;
  final Map<String, HiveSchemaType> types;

  const HiveSchema({required this.nextTypeId, required this.types});

  factory HiveSchema.fromJson(Map<String, dynamic> json) =>
      _$HiveSchemaFromJson(json);

  Map<String, dynamic> toJson() => _$HiveSchemaToJson(this);
}

@JsonSerializable()
class HiveSchemaType {
  final int nextIndex;
  final Map<String, HiveSchemaField> fields;

  const HiveSchemaType({required this.nextIndex, required this.fields});

  factory HiveSchemaType.fromJson(Map<String, dynamic> json) =>
      _$HiveSchemaTypeFromJson(json);

  Map<String, dynamic> toJson() => _$HiveSchemaTypeToJson(this);
}

@JsonSerializable()
class HiveSchemaField {
  final int index;

  const HiveSchemaField({required this.index});

  factory HiveSchemaField.fromJson(Map<String, dynamic> json) =>
      _$HiveSchemaFieldFromJson(json);

  Map<String, dynamic> toJson() => _$HiveSchemaFieldToJson(this);
}
