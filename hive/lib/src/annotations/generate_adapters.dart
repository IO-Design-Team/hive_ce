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

  /// The converters to use
  final List<BaseHiveConverter> converters;
}

/// Configuration that specifies the generation of a TypeAdapter
@immutable
class AdapterSpec<T> {
  /// Constructor
  // coverage:ignore-start
  const AdapterSpec({this.ignoredFields = const {}});
  // coverage:ignore-end

  /// Fields that should be ignored
  ///
  /// This should only be used to simplify migrations from `HiveType`
  /// annotations. Model classes should only contain fields to be persisted.
  final Set<String> ignoredFields;
}

/// Convert a type to a type Hive can store
///
/// [T] is the type to convert to/from
///
/// [S] is the type stored in Hive
@immutable
abstract class HiveConverter<T, S> {
  /// Constructor
  const HiveConverter();

  /// Convert a value from Hive
  /// Is not actually declared here to allow for generic type parameters
  // T fromHive(S value);

  /// Convert a value to Hive
  /// Is not actually declared here to allow for generic type parameters
  // S toHive(T object);
}
