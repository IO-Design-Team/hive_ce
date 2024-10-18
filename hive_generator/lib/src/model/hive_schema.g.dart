// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HiveSchema _$HiveSchemaFromJson(Map<String, dynamic> json) => HiveSchema(
      nextTypeId: (json['nextTypeId'] as num).toInt(),
      types: (json['types'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, HiveSchemaType.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$HiveSchemaToJson(HiveSchema instance) =>
    <String, dynamic>{
      'nextTypeId': instance.nextTypeId,
      'types': instance.types,
    };

HiveSchemaType _$HiveSchemaTypeFromJson(Map<String, dynamic> json) =>
    HiveSchemaType(
      nextIndex: (json['nextIndex'] as num).toInt(),
      fields: (json['fields'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, HiveSchemaField.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$HiveSchemaTypeToJson(HiveSchemaType instance) =>
    <String, dynamic>{
      'nextIndex': instance.nextIndex,
      'fields': instance.fields,
    };

HiveSchemaField _$HiveSchemaFieldFromJson(Map<String, dynamic> json) =>
    HiveSchemaField(
      index: (json['index'] as num).toInt(),
    );

Map<String, dynamic> _$HiveSchemaFieldToJson(HiveSchemaField instance) =>
    <String, dynamic>{
      'index': instance.index,
    };
