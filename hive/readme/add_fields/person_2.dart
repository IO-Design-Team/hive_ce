import 'package:meta/meta.dart';

@immutable
class Person {
  const Person({required this.name, required this.age, this.balance = 0});

  final String name;
  final int age;
  final double balance;
}
