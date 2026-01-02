import 'package:hive_ce/hive_ce.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'test_model.g.dart';

@JsonSerializable()
@HiveType(typeId: 0)
@immutable
class TestModel {
  @HiveField(0)
  final int testModelFieldZero;

  @HiveField(1)
  final int testModelFieldOne;

  @HiveField(2)
  final int testModelFieldTwo;

  @HiveField(3)
  final int testModelFieldThree;

  @HiveField(4)
  final int testModelFieldFour;

  @HiveField(5)
  final int testModelFieldFive;

  @HiveField(6)
  final int testModelFieldSix;

  @HiveField(7)
  final int testModelFieldSeven;

  @HiveField(8)
  final int testModelFieldEight;

  @HiveField(9)
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
