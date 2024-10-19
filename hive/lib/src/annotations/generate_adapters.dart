part of '../../hive.dart';

/// Annotation to generate TypeAdapters for the given [specs]
class GenerateAdapters {
  /// Constructor
  const GenerateAdapters(this.specs, {this.firstTypeId = 0});

  /// The classes to generate TypeAdapters for
  final List<AdapterSpec> specs;

  /// The first typeId to use
  final int firstTypeId;
}

/// Configuration that specifies the generation of a TypeAdapter
class AdapterSpec<T> {
  /// Constructor
  const AdapterSpec();
}
