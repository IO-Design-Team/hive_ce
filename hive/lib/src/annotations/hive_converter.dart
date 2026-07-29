import 'package:meta/meta.dart';

/// Implement this class to provide custom converters for a specific [Type].
///
/// [T] is the data type you'd like to convert to and from.
///
/// [S] is the type of the value stored in Hive. It must be a type Hive can
/// write natively (such as [String], [int], [List], [Set], or [Map]) or a type
/// with a registered [TypeAdapter].
///
/// Pass converter instances to [GenerateAdapters.converters]:
///
/// ```dart
/// class EpochDateTimeConverter implements HiveConverter<DateTime, int> {
///   const EpochDateTimeConverter();
///
///   @override
///   DateTime fromHive(int hive) =>
///       DateTime.fromMillisecondsSinceEpoch(hive);
///
///   @override
///   int toHive(DateTime object) => object.millisecondsSinceEpoch;
/// }
///
/// @GenerateAdapters(
///   [AdapterSpec<Event>()],
///   converters: [EpochDateTimeConverter()],
/// )
/// class Event {
///   final DateTime time;
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
