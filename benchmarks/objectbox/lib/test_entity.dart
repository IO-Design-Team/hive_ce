import 'package:objectbox/objectbox.dart';
import 'package:storage_benchmark/test_model.dart';

@Entity()
class TestEntity {
  @Id()
  var id = 0;

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

  TestEntity({
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

  TestEntity.fromModel(TestModel model)
    : testModelFieldZero = model.testModelFieldZero,
      testModelFieldOne = model.testModelFieldOne,
      testModelFieldTwo = model.testModelFieldTwo,
      testModelFieldThree = model.testModelFieldThree,
      testModelFieldFour = model.testModelFieldFour,
      testModelFieldFive = model.testModelFieldFive,
      testModelFieldSix = model.testModelFieldSix,
      testModelFieldSeven = model.testModelFieldSeven,
      testModelFieldEight = model.testModelFieldEight,
      testModelFieldNine = model.testModelFieldNine;
}
