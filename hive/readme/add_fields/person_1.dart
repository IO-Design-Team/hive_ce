import 'package:meta/meta.dart';

@immutable
class Person {
  const Person({required this.name, required this.age});

  final String name;
  final int age;
}
