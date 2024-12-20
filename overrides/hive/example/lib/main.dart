import 'package:hive/hive.dart';

void main() async {
  Hive.init('test');
  final box = await Hive.openBox('test');
  box.put('key', 'value');
  print(box.get('key'));
}
