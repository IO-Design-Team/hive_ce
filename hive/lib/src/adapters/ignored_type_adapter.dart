import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';

/// Not part of public API
@immutable
class IgnoredTypeAdapter<T> implements TypeAdapter<T?> {
  /// Constructor
  const IgnoredTypeAdapter([this.typeId = 0]);

  @override
  final int typeId;

  @override
  T? read(BinaryReader reader) => null;

  @override
  void write(BinaryWriter writer, obj) {}
}
