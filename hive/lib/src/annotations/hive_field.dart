import 'package:meta/meta_meta.dart';
import 'package:meta/meta.dart';

/// Annotate all fields you want to persist with [HiveField].
@Target({
  TargetKind.field,
  TargetKind.getter,
  TargetKind.setter,
  TargetKind.enumValue,
  TargetKind.parameter,
})
@immutable
class HiveField {
  /// The index of this field.
  final int index;

  /// The default value of this field for class hive types.
  ///
  /// This value takes precedence over constructor parameter default values.
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
