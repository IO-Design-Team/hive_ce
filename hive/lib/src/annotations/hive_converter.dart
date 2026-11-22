import 'package:meta/meta.dart';

/// Converts a field of type [T] to and from a type [S] that Hive can store
///
/// Pass instances to `GenerateAdapters.converters`. A converter applies to
/// matching fields and values inside `List`, `Set`, `Iterable`, and `Map`
/// types.
///
/// Unless [T] is nullable, null values are not passed to the converter. Generic
/// converters can either be passed without type arguments to infer them from
/// each field, or with concrete type arguments to match a specific type.
///
/// ```dart
/// class UriConverter extends HiveConverter<Uri, String> {
///   const UriConverter();
///
///   @override
///   Uri fromHive(String value) => Uri.parse(value);
///
///   @override
///   String toHive(Uri value) => value.toString();
/// }
///
/// @GenerateAdapters([AdapterSpec<Website>()], converters: [UriConverter()])
/// part 'hive_adapters.g.dart';
/// ```
@immutable
abstract class HiveConverter<T, S> {
  /// Constructor
  // coverage:ignore-start
  const HiveConverter();
  // coverage:ignore-end

  /// Convert a value read from Hive to [T]
  T fromHive(S value);

  /// Convert [value] to a value Hive can store
  S toHive(T value);
}
