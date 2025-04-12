import 'dart:io';

import 'package:example/hive/hive_registrar.g.dart';
import 'package:hive_ce/hive.dart';

class Person {
  Person({required this.name, required this.age, this.friends = const []});

  final String name;
  final int age;
  final List<Person> friends;

  @override
  String toString() {
    return '$name: $age';
  }
}

void main() async {
  final path = Directory.current.path;
  Hive
    ..init(path)
    ..registerAdapters();

  final box = await Hive.openBox('testBox');

  final person = Person(
    name: 'Dave',
    age: 22,
    friends: [
      Person(name: 'Linda', age: 20),
      Person(name: 'Marc', age: 21),
      Person(name: 'Anne', age: 22),
    ],
  );

  await box.put('dave', person);

  print(box.get('dave')); // Dave: 22
}
