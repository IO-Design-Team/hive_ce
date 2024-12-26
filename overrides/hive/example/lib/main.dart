import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';

void main() async {
  Hive.init('test');
  final box = await Hive.openBox('test');
  box.put('key', 'value');
  print(box.get('key'));

  final impl = HiveImpl();
  impl.box('test');
}
