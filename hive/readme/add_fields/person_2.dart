import 'package:hive_ce/hive.dart';

@HiveType(typeId: 0)
class Person extends HiveObject {
  Person({required this.name, required this.age, this.balance = 0});

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @HiveField(2)
  double balance;
}
