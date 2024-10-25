import 'package:hive_ce/hive.dart';

class Person extends HiveObject {
  Person({required this.name, required this.age, this.balance = 0});

  String name;
  int age;
  double balance;
}
