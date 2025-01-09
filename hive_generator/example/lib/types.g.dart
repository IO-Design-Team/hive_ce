// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: unnecessary_const, require_trailing_commas, document_ignores

part of 'types.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class Class1Adapter extends TypeAdapter<Class1> {
  @override
  final int typeId = 1;

  @override
  Class1 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Class1(
      fields[0] == null
          ? const Class2(4, 'param', {
              5: {
                'magic': [
                  const Class1(const Class2(5, 'sad')),
                  const Class1(const Class2(5, 'sad'), Enum1.emumValue1)
                ]
              },
              67: {
                'hold': [const Class1(const Class2(42, 'meaning of life'))]
              }
            })
          : fields[0] as Class2,
    );
  }

  @override
  void write(BinaryWriter writer, Class1 obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.nested);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Class1Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class Class2Adapter extends TypeAdapter<Class2> {
  @override
  final int typeId = 2;

  @override
  Class2 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Class2(
      fields[0] == null ? 0 : (fields[0] as num).toInt(),
      fields[1] as String,
      (fields[6] as Map?)?.map((dynamic k, dynamic v) => MapEntry(
          (k as num).toInt(),
          (v as Map).map((dynamic k, dynamic v) =>
              MapEntry(k as String, (v as List).cast<Class1>())))),
    );
  }

  @override
  void write(BinaryWriter writer, Class2 obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.param1)
      ..writeByte(1)
      ..write(obj.param2)
      ..writeByte(6)
      ..write(obj.what);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Class2Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EmptyClassAdapter extends TypeAdapter<EmptyClass> {
  @override
  final int typeId = 4;

  @override
  EmptyClass read(BinaryReader reader) {
    return EmptyClass();
  }

  @override
  void write(BinaryWriter writer, EmptyClass obj) {
    writer.writeByte(0);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmptyClassAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IterableClassAdapter extends TypeAdapter<IterableClass> {
  @override
  final int typeId = 5;

  @override
  IterableClass read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IterableClass(
      (fields[0] as List).cast<String>(),
      (fields[1] as Set).cast<String>(),
      (fields[2] as List).map((e) => (e as Set).cast<String>()).toList(),
      (fields[3] as Set).map((e) => (e as List).cast<String>()).toSet(),
    );
  }

  @override
  void write(BinaryWriter writer, IterableClass obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.list)
      ..writeByte(1)
      ..write(obj.set)
      ..writeByte(2)
      ..write(obj.nestedList)
      ..writeByte(3)
      ..write(obj.nestedSet);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IterableClassAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConstructorDefaultsAdapter extends TypeAdapter<ConstructorDefaults> {
  @override
  final int typeId = 6;

  @override
  ConstructorDefaults read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConstructorDefaults(
      a: fields[0] == null ? 42 : (fields[0] as num).toInt(),
      b: fields[1] == null ? '6 * 7' : fields[1] as String,
      c: fields[2] == null ? true : fields[2] as bool,
      d: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ConstructorDefaults obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.a)
      ..writeByte(1)
      ..write(obj.b)
      ..writeByte(2)
      ..write(obj.c)
      ..writeByte(3)
      ..write(obj.d);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstructorDefaultsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NullableTypesAdapter extends TypeAdapter<NullableTypes> {
  @override
  final int typeId = 7;

  @override
  NullableTypes read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NullableTypes(
      a: (fields[0] as num?)?.toInt(),
      b: fields[1] as String?,
      c: fields[2] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, NullableTypes obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.a)
      ..writeByte(1)
      ..write(obj.b)
      ..writeByte(2)
      ..write(obj.c);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NullableTypesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NamedImportsAdapter extends TypeAdapter<NamedImports> {
  @override
  final int typeId = 8;

  @override
  NamedImports read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NamedImports(
      fields[0] as named.NamedImportType,
      (fields[1] as List).cast<named.NamedImportType>(),
      fields[2] as named.NamedImportType?,
      (fields[3] as Map).cast<named.NamedImportType, named.NamedImportType>(),
    );
  }

  @override
  void write(BinaryWriter writer, NamedImports obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.namedImportType)
      ..writeByte(1)
      ..write(obj.namedImportTypeList)
      ..writeByte(2)
      ..write(obj.namedImportTypeNullable)
      ..writeByte(3)
      ..write(obj.namedImportTypeMap);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NamedImportsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class Enum1Adapter extends TypeAdapter<Enum1> {
  @override
  final int typeId = 3;

  @override
  Enum1 read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Enum1.emumValue1;
      case 1:
        return Enum1.emumValue2;
      case 2:
        return Enum1.emumValue3;
      default:
        return Enum1.emumValue2;
    }
  }

  @override
  void write(BinaryWriter writer, Enum1 obj) {
    switch (obj) {
      case Enum1.emumValue1:
        writer.writeByte(0);
      case Enum1.emumValue2:
        writer.writeByte(1);
      case Enum1.emumValue3:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Enum1Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
