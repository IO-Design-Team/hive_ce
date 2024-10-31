import 'dart:async';
import 'dart:io';

import 'package:common_storage_benchmark/db_type.dart';
import 'package:common_storage_benchmark/test_model.dart';

const _boxName = 'test_box';
const _iterations = 100000;
const _model = TestModel(
  testModelFieldZero: 0,
  testModelFieldOne: 1,
  testModelFieldTwo: 2,
  testModelFieldThree: 3,
  testModelFieldFour: 4,
  testModelFieldFive: 5,
  testModelFieldSix: 6,
  testModelFieldSeven: 7,
  testModelFieldEight: 8,
  testModelFieldNine: 9,
);

Future<void> runBenchmark({
  required DbType type,
  required FutureOr<dynamic> Function(String name) openBox,
}) async {
  final box = await openBox(_boxName);
  for (var i = 0; i < _iterations; i++) {
    await box.add(_model);
  }

  final boxFile = File(type.boxFileName(_boxName));
  final size = boxFile.lengthSync();
  final megabytes = (size / 1024 / 1024).toStringAsFixed(2);
  print('Size: $megabytes MB');
}