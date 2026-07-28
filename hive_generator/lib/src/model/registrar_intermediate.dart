import 'package:meta/meta.dart';

/// Intermediate information to generate the Hive registrar
@immutable
class RegistrarIntermediate {
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
      RegistrarIntermediate(
        uri: Uri.parse(json['uri'] as String),
        adapters: (json['adapters'] as List).cast<String>(),
        registrarLocation: json['registrarLocation'] as bool,
      );

  /// To json
  Map<String, dynamic> toJson() => {
        'uri': uri.toString(),
        'adapters': adapters,
        'registrarLocation': registrarLocation,
      };
}
