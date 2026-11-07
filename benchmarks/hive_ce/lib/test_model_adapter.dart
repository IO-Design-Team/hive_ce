import 'package:hive_ce/hive_ce.dart';
import 'package:storage_benchmark/test_model.dart';

class TestModelAdapter extends TypeAdapter<TestModel> {
  @override
  final typeId = 0;

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
}
