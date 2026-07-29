import 'package:hive_ce/src/annotations/hive_converter.dart';
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
    this.converters = const [],
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

  /// A list of [HiveConverter]s to apply when generating adapters for [specs]
  ///
  /// These converters are used when a matching converter is not found on the
  /// field or class. See [HiveConverter] for details.
  final List<HiveConverter> converters;
}

/// Configuration that specifies the generation of a TypeAdapter
@immutable
class AdapterSpec<T> {
  /// Constructor
  // coverage:ignore-start
  const AdapterSpec({
    this.ignoredFields = const {},
    this.converters = const [],
  });
  // coverage:ignore-end

  /// Fields that should be ignored
  ///
  /// This should only be used to simplify migrations from `HiveType`
  /// annotations. Model classes should only contain fields to be persisted.
  final Set<String> ignoredFields;

  /// A list of [HiveConverter]s to apply when generating an adapter for [T]
  ///
  /// These converters take precedence over [GenerateAdapters.converters], but
  /// are overridden by converters placed on the class or field. See
  /// [HiveConverter] for details.
  final List<HiveConverter> converters;
}
