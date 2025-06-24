import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import 'integration.dart';
import 'package:meta/meta.dart';

@immutable
class TestObject {
  const TestObject(this.value);

  final int value;
}

class TestAdapter extends TypeAdapter<TestObject> {
  const TestAdapter();

  @override
  final typeId = 10;

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
  hiveIntegrationTest((type) {
    test('ignore typeId with IgnoredTypeAdapter', () async {
      final (hive, box1) = await openBox(false, type: type);

      await hive.registerAdapter(TestAdapter());

      await box1.put(1, TestObject(5));
      await box1.put(2, 42);
      await box1.put(3, 78);

      await hive.resetAdapters();
      await hive.ignoreTypeId(10);
      final box2 = await hive.reopenBox(box1);

      expect(box2, isNotNull);
      expect(await box2.get(1), null);
      expect(await box2.get(2), 42);
      expect(await box2.get(3), 78);
    });
  });
}
