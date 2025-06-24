import 'dart:io';

import 'package:example/hive/hive_registrar.g.dart';
import 'package:example/main.dart';
import 'package:hive_ce/hive.dart';

void main() async {
  final path = Directory.current.path;
  Hive.init(path);
  Hive.registerAdapters();

  final box1 = await Hive.openBox('testBox');
  box1.inspect();

  final box2 = await Hive.openBox('testBox2');
  box2.inspect();

  final john = Person(name: 'John', age: 30);
  final jane = Person(
    name: 'Jane',
    age: 25,
    bestFriend: john,
    friends: [john, john, john, Person(name: 'Joe', age: 22, bestFriend: john)],
  );
  await box2.put('person1', john);
  await box2.put('person2', jane);

  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    await box1.add('bump');
  }
}
