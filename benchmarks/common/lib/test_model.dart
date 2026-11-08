import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'test_model.g.dart';

/// The value written in every benchmark
const testModel = TestModel(
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

@JsonSerializable()
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

  factory TestModel.fromJson(Map<String, dynamic> json) =>
      _$TestModelFromJson(json);

  Map<String, dynamic> toJson() => _$TestModelToJson(this);
}
