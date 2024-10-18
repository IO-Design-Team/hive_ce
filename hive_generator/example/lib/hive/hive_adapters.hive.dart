part of 'hive_adapters.dart';    class ClassSpec2Adapter extends TypeAdapter<ClassSpec2> {
      @override
      final int typeId = 0;

      @override
      ClassSpec2 read(BinaryReader reader) {
            final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return ClassSpec2(
    
fields[0] as String,
)
;

      }

      @override
      void write(BinaryWriter writer, ClassSpec2 obj) {
        writer
..writeByte(1)
      ..writeByte(0)
      ..write(obj.value)
;

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
        class ClassSpec1Adapter extends TypeAdapter<ClassSpec1> {
      @override
      final int typeId = 1;

      @override
      ClassSpec1 read(BinaryReader reader) {
            final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return ClassSpec1(
    
(fields[0] as num).toInt(),
)
;

      }

      @override
      void write(BinaryWriter writer, ClassSpec1 obj) {
        writer
..writeByte(1)
      ..writeByte(0)
      ..write(obj.value)
;

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
    