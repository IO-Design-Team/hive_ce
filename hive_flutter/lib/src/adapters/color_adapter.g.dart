// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: public_member_api_docs

part of 'color_adapter.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveColorAdapter extends TypeAdapter<HiveColor> {
  @override
  final int typeId = 200;

  @override
  HiveColor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveColor(
      a: (fields[0] as num).toDouble(),
      r: (fields[1] as num).toDouble(),
      g: (fields[2] as num).toDouble(),
      b: (fields[3] as num).toDouble(),
      colorSpace: (fields[4] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveColor obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.a)
      ..writeByte(1)
      ..write(obj.r)
      ..writeByte(2)
      ..write(obj.g)
      ..writeByte(3)
      ..write(obj.b)
      ..writeByte(4)
      ..write(obj.colorSpace);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveColorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
