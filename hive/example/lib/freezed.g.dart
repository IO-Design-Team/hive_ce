// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'freezed.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FreezedPersonAdapter extends TypeAdapter<FreezedPerson> {
  @override
  final int typeId = 100;

  @override
  FreezedPerson read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FreezedPerson(
      firstName: fields[0] as String,
      lastName: fields[1] as String,
      age: (fields[2] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, FreezedPerson obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.firstName)
      ..writeByte(1)
      ..write(obj.lastName)
      ..writeByte(2)
      ..write(obj.age);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreezedPersonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
