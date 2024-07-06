part of '../../hive.dart';

/// Annotate all fields you want to persist with [HiveField].
// TODO: Enable when Flutter supports analyser 6.5.0
// @Target({
//   TargetKind.field,
//   TargetKind.getter,
//   TargetKind.setter,
//   TargetKind.enumValue,
// })
class HiveField {
  /// The index of this field.
  final int index;

  /// The default value of this field for class hive types.
  ///
  /// In enum hive types set `true` to use this enum value as default value
  /// instead of null in null-safety.
  ///
  /// ```dart
  /// @HiveType(typeId: 1)
  /// enum MyEnum {
  ///   @HiveField(0)
  ///   apple,
  ///
  ///   @HiveField(1, defaultValue: true)
  ///   pear
  /// }
  /// ```
  final dynamic defaultValue;

  /// TODO: Document this!
  const HiveField(this.index, {this.defaultValue});
}
