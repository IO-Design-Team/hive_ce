/// Annotation to generate TypeAdapters for the given [specs]
class GenerateAdapters {
  /// Constructor
  // coverage:ignore-start
  const GenerateAdapters(this.specs, {this.firstTypeId = 0});
  // coverage:ignore-end

  /// The classes to generate TypeAdapters for
  final List<AdapterSpec> specs;

  /// The first typeId to use
  final int firstTypeId;
}

/// Configuration that specifies the generation of a TypeAdapter
class AdapterSpec<T> {
  /// Constructor
  // coverage:ignore-start
  const AdapterSpec();
  // coverage:ignore-end
}
