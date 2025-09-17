// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_connect_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InspectorFrame _$InspectorFrameFromJson(Map<String, dynamic> json) =>
    InspectorFrame(
      key: json['key'] as Object,
      value: json['value'],
      lazy: json['lazy'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$InspectorFrameToJson(InspectorFrame instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'lazy': instance.lazy,
      'deleted': instance.deleted,
    };

BoxEventPayload _$BoxEventPayloadFromJson(Map<String, dynamic> json) =>
    BoxEventPayload(
      box: json['box'] as String,
      frame: InspectorFrame.fromJson(json['frame'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BoxEventPayloadToJson(BoxEventPayload instance) =>
    <String, dynamic>{
      'box': instance.box,
      'frame': instance.frame,
    };
