import 'package:hive_ce/hive.dart';

class Person extends HiveObject {
  Person({required this.name, required this.age});

  String name;
  int age;
}
