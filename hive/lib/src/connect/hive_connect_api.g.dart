// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_connect_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InspectorFrame _$InspectorFrameFromJson(Map<String, dynamic> json) =>
    InspectorFrame(
      key: json['key'],
      value: json['value'],
      lazy: json['lazy'] as bool,
    );

Map<String, dynamic> _$InspectorFrameToJson(InspectorFrame instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'lazy': instance.lazy,
    };

BoxEventPayload _$BoxEventPayloadFromJson(Map<String, dynamic> json) =>
    BoxEventPayload(
      name: json['name'] as String,
      key: json['key'],
      value: (json['value'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      deleted: json['deleted'] as bool,
    );

Map<String, dynamic> _$BoxEventPayloadToJson(BoxEventPayload instance) =>
    <String, dynamic>{
      'name': instance.name,
      'key': instance.key,
      'value': instance.value,
      'deleted': instance.deleted,
    };
