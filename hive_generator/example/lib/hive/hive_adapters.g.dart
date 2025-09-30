// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: unnecessary_const, require_trailing_commas, document_ignores

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class ClassSpec1Adapter extends TypeAdapter<ClassSpec1> {
  @override
  final typeId = 50;

  @override
  ClassSpec1 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassSpec1((fields[0] as num).toInt(), (fields[1] as num).toInt());
  }

  @override
  void write(BinaryWriter writer, ClassSpec1 obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.value)
      ..writeByte(1)
      ..write(obj.value2);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassSpec1Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ClassSpec2Adapter extends TypeAdapter<ClassSpec2> {
  @override
  final typeId = 51;

  @override
  ClassSpec2 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassSpec2(
      fields[0] as String,
      fields[1] as String,
      (fields[2] as List).cast<String>(),
      (fields[3] as Set).cast<String>(),
      (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ClassSpec2 obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.value)
      ..writeByte(1)
      ..write(obj.value2)
      ..writeByte(2)
      ..write(obj.iterable)
      ..writeByte(3)
      ..write(obj.set)
      ..writeByte(4)
      ..write(obj.list);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassSpec2Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EnumSpecAdapter extends TypeAdapter<EnumSpec> {
  @override
  final typeId = 52;

  @override
  EnumSpec read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EnumSpec.value1;
      case 1:
        return EnumSpec.value2;
      default:
        return EnumSpec.value1;
    }
  }

  @override
  void write(BinaryWriter writer, EnumSpec obj) {
    switch (obj) {
      case EnumSpec.value1:
        writer.writeByte(0);
      case EnumSpec.value2:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnumSpecAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ClassSpec3Adapter extends TypeAdapter<ClassSpec3> {
  @override
  final typeId = 53;

  @override
  ClassSpec3 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassSpec3()..value = (fields[0] as num?)?.toInt();
  }

  @override
  void write(BinaryWriter writer, ClassSpec3 obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassSpec3Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ClassSpec4Adapter extends TypeAdapter<ClassSpec4> {
  @override
  final typeId = 54;

  @override
  ClassSpec4 read(BinaryReader reader) {
    reader.readByte();
    return ClassSpec4();
  }

  @override
  void write(BinaryWriter writer, ClassSpec4 obj) {
    writer.writeByte(0);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassSpec4Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
