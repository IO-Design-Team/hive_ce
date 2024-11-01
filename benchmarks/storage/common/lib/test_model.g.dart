// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TestModelAdapter extends TypeAdapter<TestModel> {
  @override
  final int typeId = 0;

  @override
  TestModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestModel(
      testModelFieldZero: (fields[0] as num).toInt(),
      testModelFieldOne: (fields[1] as num).toInt(),
      testModelFieldTwo: (fields[2] as num).toInt(),
      testModelFieldThree: (fields[3] as num).toInt(),
      testModelFieldFour: (fields[4] as num).toInt(),
      testModelFieldFive: (fields[5] as num).toInt(),
      testModelFieldSix: (fields[6] as num).toInt(),
      testModelFieldSeven: (fields[7] as num).toInt(),
      testModelFieldEight: (fields[8] as num).toInt(),
      testModelFieldNine: (fields[9] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, TestModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.testModelFieldZero)
      ..writeByte(1)
      ..write(obj.testModelFieldOne)
      ..writeByte(2)
      ..write(obj.testModelFieldTwo)
      ..writeByte(3)
      ..write(obj.testModelFieldThree)
      ..writeByte(4)
      ..write(obj.testModelFieldFour)
      ..writeByte(5)
      ..write(obj.testModelFieldFive)
      ..writeByte(6)
      ..write(obj.testModelFieldSix)
      ..writeByte(7)
      ..write(obj.testModelFieldSeven)
      ..writeByte(8)
      ..write(obj.testModelFieldEight)
      ..writeByte(9)
      ..write(obj.testModelFieldNine);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TestModel _$TestModelFromJson(Map<String, dynamic> json) => TestModel(
      testModelFieldZero: (json['testModelFieldZero'] as num).toInt(),
      testModelFieldOne: (json['testModelFieldOne'] as num).toInt(),
      testModelFieldTwo: (json['testModelFieldTwo'] as num).toInt(),
      testModelFieldThree: (json['testModelFieldThree'] as num).toInt(),
      testModelFieldFour: (json['testModelFieldFour'] as num).toInt(),
      testModelFieldFive: (json['testModelFieldFive'] as num).toInt(),
      testModelFieldSix: (json['testModelFieldSix'] as num).toInt(),
      testModelFieldSeven: (json['testModelFieldSeven'] as num).toInt(),
      testModelFieldEight: (json['testModelFieldEight'] as num).toInt(),
      testModelFieldNine: (json['testModelFieldNine'] as num).toInt(),
    );

Map<String, dynamic> _$TestModelToJson(TestModel instance) => <String, dynamic>{
      'testModelFieldZero': instance.testModelFieldZero,
      'testModelFieldOne': instance.testModelFieldOne,
      'testModelFieldTwo': instance.testModelFieldTwo,
      'testModelFieldThree': instance.testModelFieldThree,
      'testModelFieldFour': instance.testModelFieldFour,
      'testModelFieldFive': instance.testModelFieldFive,
      'testModelFieldSix': instance.testModelFieldSix,
      'testModelFieldSeven': instance.testModelFieldSeven,
      'testModelFieldEight': instance.testModelFieldEight,
      'testModelFieldNine': instance.testModelFieldNine,
    };
