import 'package:meta/meta.dart';

/// Implement this class to provide custom converters for a specific [Type].
///
/// [T] is the data type you'd like to convert to and from.
///
/// [S] is the type of the value stored in Hive. It must be a type Hive can
/// write natively (such as [String], [int], [List], [Set], or [Map]) or a type
/// with a registered [TypeAdapter].
///
/// [HiveConverter]s can be placed either on the class:
///
/// ```dart
/// class MyHiveConverter extends HiveConverter<Value, String> {
///   const MyHiveConverter();
///
///   @override
///   Value fromHive(String hive) => Value(hive);
///
///   @override
///   String toHive(Value object) => object.toString();
/// }
///
/// @GenerateAdapters([AdapterSpec<Example>()])
/// @MyHiveConverter()
/// class Example {
///   final Value property;
/// }
/// ```
///
/// or on a property:
///
/// ```dart
/// @GenerateAdapters([AdapterSpec<Example>()])
/// class Example {
///   @MyHiveConverter()
///   final Value property;
/// }
/// ```
///
/// Or finally, passed to the [GenerateAdapters] or [AdapterSpec] annotation:
///
/// ```dart
/// @GenerateAdapters(
///   [AdapterSpec<Example>()],
///   converters: [MyHiveConverter()],
/// )
/// class Example {
///   final Value property;
/// }
/// ```
@immutable
abstract class HiveConverter<T, S> {
  /// Constructor
  const HiveConverter();

  /// Convert a value read from Hive into [T].
  T fromHive(S hive);

  /// Convert a [T] value into a value Hive can write.
  S toHive(T object);
}
