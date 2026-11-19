import 'package:meta/meta.dart';

/// The first field is distinct so a query can select a subset of the values.
List<TestModel> testModels(int count) =>
    List.generate(count, TestModel.withIndex);

List<TestModel> modelsInRange(Iterable<TestModel> values, int min, int max) =>
    values.where((value) => value.matchesRange(min, max)).toList();

@immutable
class TestModel {
  final int testModelFieldZero;
  final int testModelFieldOne;
  final int testModelFieldTwo;
  final int testModelFieldThree;
  final int testModelFieldFour;
  final int testModelFieldFive;
  final int testModelFieldSix;
  final int testModelFieldSeven;
  final int testModelFieldEight;
  final int testModelFieldNine;

  const TestModel({
    required this.testModelFieldZero,
    required this.testModelFieldOne,
    required this.testModelFieldTwo,
    required this.testModelFieldThree,
    required this.testModelFieldFour,
    required this.testModelFieldFive,
    required this.testModelFieldSix,
    required this.testModelFieldSeven,
    required this.testModelFieldEight,
    required this.testModelFieldNine,
  });

  const TestModel.withIndex(int index)
    : testModelFieldZero = index,
      testModelFieldOne = 1,
      testModelFieldTwo = 2,
      testModelFieldThree = 3,
      testModelFieldFour = 4,
      testModelFieldFive = 5,
      testModelFieldSix = 6,
      testModelFieldSeven = 7,
      testModelFieldEight = 8,
      testModelFieldNine = 9;

  bool matchesRange(int min, int max) =>
      testModelFieldZero >= min && testModelFieldZero < max;

  factory TestModel.fromJson(Map<String, dynamic> json) => TestModel(
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

  Map<String, dynamic> toJson() => {
    'testModelFieldZero': testModelFieldZero,
    'testModelFieldOne': testModelFieldOne,
    'testModelFieldTwo': testModelFieldTwo,
    'testModelFieldThree': testModelFieldThree,
    'testModelFieldFour': testModelFieldFour,
    'testModelFieldFive': testModelFieldFive,
    'testModelFieldSix': testModelFieldSix,
    'testModelFieldSeven': testModelFieldSeven,
    'testModelFieldEight': testModelFieldEight,
    'testModelFieldNine': testModelFieldNine,
  };
}
