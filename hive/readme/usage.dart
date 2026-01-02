import 'package:hive_ce/hive_ce.dart';

void example() {
  final box = Hive.box('myBox');
  box.put('name', 'David');
  final name = box.get('name');
  print('Name: $name');
}
