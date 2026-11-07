import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'test_model.g.dart';

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
