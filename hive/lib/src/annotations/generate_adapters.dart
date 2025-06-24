import 'package:meta/meta.dart';

/// Annotation to generate TypeAdapters for the given [specs]
@immutable
class GenerateAdapters {
  /// Constructor
  // coverage:ignore-start
  const GenerateAdapters(
    this.specs, {
    this.firstTypeId = 0,
    this.reservedTypeIds = const {},
  });
  // coverage:ignore-end

  /// The classes to generate TypeAdapters for
  final List<AdapterSpec> specs;

  /// The first typeId to use
  final int firstTypeId;

  /// Reserved type ids
  ///
  /// These type ids will be skipped during generation
  final Set<int> reservedTypeIds;
}

/// Configuration that specifies the generation of a TypeAdapter
class AdapterSpec<T> {
  /// Constructor
  // coverage:ignore-start
  const AdapterSpec();
  // coverage:ignore-end
}
