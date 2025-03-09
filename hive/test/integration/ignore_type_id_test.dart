import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import 'integration.dart';

class TestObject {
  TestObject(this.value);

  final int value;
}

class TestAdapter extends TypeAdapter<TestObject> {
  TestAdapter();

  @override
  final int typeId = 10;

  @override
  TestObject read(BinaryReader reader) {
    return TestObject(reader.readInt32());
  }

  @override
  void write(BinaryWriter writer, obj) {
    writer.writeInt32(obj.value);
  }
}

void main() {
  hiveIntegrationTest((isolated) {
    test('ignore typeId with IgnoredTypeAdapter', () async {
      final hive = await createHive(isolated: isolated);
      final box1 = await hive.openBox('test');

      await hive.registerAdapter(TestAdapter());

      await box1.put(1, TestObject(5));
      await box1.put(2, 42);
      await box1.put(3, 78);
      await box1.close();

      await hive.resetAdapters();
      await hive.ignoreTypeId(10);

      final box2 = await hive.openBox('test');

      expect(box2, isNotNull);
      expect(await box2.get(1), null);
      expect(await box2.get(2), 42);
      expect(await box2.get(3), 78);
    });
  });
}
