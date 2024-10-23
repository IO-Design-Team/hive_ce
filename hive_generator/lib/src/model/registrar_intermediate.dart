import 'package:json_annotation/json_annotation.dart';

part 'registrar_intermediate.g.dart';

/// Intermediate information to generate the Hive registrar
@JsonSerializable()
class RegistrarIntermediate {
  /// Error when multiple GenerateAdapters annotations are found
  static const multipleGenerateAdaptersError =
      'Only one GenerateAdapters annotation is allowed';

  /// The URI of the file this intermediate describes
  final Uri uri;

  /// The names of the adapters
  final List<String> adapters;

  /// If this is where the Hive registrar should be placed
  ///
  /// Only one intermediate may have this set to true
  final bool registrarLocation;

  /// Constructor
  const RegistrarIntermediate({
    required this.uri,
    required this.adapters,
    required this.registrarLocation,
  });

  /// From json
  factory RegistrarIntermediate.fromJson(Map<String, dynamic> json) =>
      _$RegistrarIntermediateFromJson(json);

  /// To json
  Map<String, dynamic> toJson() => _$RegistrarIntermediateToJson(this);
}
