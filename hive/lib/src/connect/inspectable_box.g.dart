// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspectable_box.dart';

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
