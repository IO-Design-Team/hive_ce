import 'package:hive_ce/hive.dart';

/// Not part of public API
class IgnoredTypeAdapter<T> implements TypeAdapter<T?> {
  /// TODO: Document this!
  const IgnoredTypeAdapter([this.typeId = 0]);

  @override
  final int typeId;

  @override
  T? read(BinaryReader reader) => null;

  @override
  void write(BinaryWriter writer, obj) {}
}
