import 'package:storage_benchmark/test_model.dart';

/// Keeps the fixture's field IDs and encoding shared by Hive CE and Hive v2.
TestModel readHiveFixture(int Function() readByte, Object? Function() read) {
  final count = readByte();
  final fields = <int, Object?>{
    for (var i = 0; i < count; i++) readByte(): read(),
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

void writeHiveFixture(
  TestModel value,
  void Function(int) writeByte,
  void Function(int) write,
) {
  writeByte(10);
  writeByte(0);
  write(value.testModelFieldZero);
  writeByte(1);
  write(value.testModelFieldOne);
  writeByte(2);
  write(value.testModelFieldTwo);
  writeByte(3);
  write(value.testModelFieldThree);
  writeByte(4);
  write(value.testModelFieldFour);
  writeByte(5);
  write(value.testModelFieldFive);
  writeByte(6);
  write(value.testModelFieldSix);
  writeByte(7);
  write(value.testModelFieldSeven);
  writeByte(8);
  write(value.testModelFieldEight);
  writeByte(9);
  write(value.testModelFieldNine);
}
