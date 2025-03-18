import 'package:hive_ce/hive.dart';

import 'stub_ins.dart';

void main() async {
  await IsolatedHive.init('.', isolateNameServer: StubIns());
  final box = await IsolatedHive.openBox('box');
  await box.put('key', 'value');
  print(await box.get('key')); // reading is async
}
