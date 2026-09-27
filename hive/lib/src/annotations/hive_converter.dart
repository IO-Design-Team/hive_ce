import 'package:meta/meta.dart';

/// Converts a field of type [T] to and from a type [S] that Hive can store
///
/// Pass instances to [GenerateAdapters.converters]. A converter is used for
/// values whose type is exactly [T] (ignoring nullability), including values
/// inside [List], [Set], and [Map] fields. Null values are not passed to the
/// converter.
///
/// Converters must have a const unnamed constructor with no arguments. Generic
/// converters must be given concrete type arguments.
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
  const HiveConverter();

  /// Convert a value read from Hive to [T]
  T fromHive(S value);

  /// Convert [value] to a value Hive can store
  S toHive(T value);
}
