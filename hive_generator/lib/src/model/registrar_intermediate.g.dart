// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, require_trailing_commas

part of 'registrar_intermediate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegistrarIntermediate _$RegistrarIntermediateFromJson(Map<String, dynamic> json) => RegistrarIntermediate(
      uri: Uri.parse(json['uri'] as String),
      adapters: (json['adapters'] as List<dynamic>).map((e) => e as String).toList(),
      registrarLocation: json['registrarLocation'] as bool,
    );

Map<String, dynamic> _$RegistrarIntermediateToJson(RegistrarIntermediate instance) => <String, dynamic>{
      'uri': instance.uri.toString(),
      'adapters': instance.adapters,
      'registrarLocation': instance.registrarLocation,
    };
