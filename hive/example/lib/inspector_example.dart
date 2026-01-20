import 'dart:io';

import 'package:example/hive/hive_registrar.g.dart';
import 'package:example/main.dart';
import 'package:hive_ce/hive_ce.dart';

void main() async {
  final path = Directory.current.path;
  Hive.init(path);
  Hive.registerAdapters();
  await IsolatedHive.init(path);
  IsolatedHive.registerAdapters();

  final box2 = await Hive.openBox('testBox2');

  final john = Person(name: 'John', age: 30);
  final jane = Person(
    name: 'Jane',
    age: 25,
    bestFriend: john,
    friends: [
      john,
      john,
      john,
      Person(name: 'Joe', age: 22, bestFriend: john),
    ],
  );
  await box2.put('person1', john);
  await box2.put('person2', jane);

  final box3 = await IsolatedHive.openBox('isolatedBox');
  await box3.add(john);

  var box4 = await Hive.openLazyBox('lazyBox');
  for (var i = 0; i < 1000; i++) {
    await box4.add(john);
  }
  await box4.close();
  box4 = await Hive.openLazyBox('lazyBox');

  final box5 = await Hive.openBox('box5');
  for (var i = 0; i < 1000000; i++) {
    await box5.put(i, john);
  }

  bump();
  toggleBoxRegistration();
}

void bump() async {
  final box1 = await Hive.openBox('testBox');
  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    print('bump');
    await box1.add('bump');
  }
}

void toggleBoxRegistration() async {
  while (true) {
    final box = await Hive.openBox('tempBox');
    print('tempBox opened');
    await Future.delayed(const Duration(seconds: 5));
    await box.close();
    print('tempBox closed');
    await Future.delayed(const Duration(seconds: 5));
  }
}
