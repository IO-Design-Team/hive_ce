import 'dart:io';

import 'package:hive_ce/hive.dart';

part 'main.g.dart';

@HiveType(typeId: 1)

/// TODO: Document this!
class Person {
  /// TODO: Document this!
  Person({required this.name, required this.age, required this.friends});

  @HiveField(0)

  /// TODO: Document this!
  String name;

  @HiveField(1)

  /// TODO: Document this!
  int age;

  @HiveField(2)

  /// TODO: Document this!
  List<String> friends;

  @override
  String toString() {
    return '$name: $age';
  }
}

void main() async {
  final path = Directory.current.path;
  Hive
    ..init(path)
    ..registerAdapter(PersonAdapter());

  final box = await Hive.openBox('testBox');

  final person = Person(
    name: 'Dave',
    age: 22,
    friends: ['Linda', 'Marc', 'Anne'],
  );

  await box.put('dave', person);

  print(box.get('dave')); // Dave: 22
}
