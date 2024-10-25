import 'package:hive_ce/hive.dart';
import 'person.dart';

void example() async {
  final box = await Hive.openBox('myBox');

  final person = Person(name: 'Dave', age: 22);
  await box.add(person);

  print(box.getAt(0)); // Dave - 22

  person.age = 30;
  await person.save();

  print(box.getAt(0)); // Dave - 30
}
