import 'package:json_annotation/json_annotation.dart';

part 'registrar_intermediate.g.dart';

/// Intermediate information to generate the Hive registrar
@JsonSerializable()
class RegistrarIntermediate {
  /// The URI of the file this intermediate describes
  final Uri uri;

  /// The names of the adapters
  final List<String> adapters;

  /// Constructor
  const RegistrarIntermediate({
    required this.uri,
    required this.adapters,
  });

  /// From json
  factory RegistrarIntermediate.fromJson(Map<String, dynamic> json) =>
      _$RegistrarIntermediateFromJson(json);

  /// To json
  Map<String, dynamic> toJson() => _$RegistrarIntermediateToJson(this);
}
