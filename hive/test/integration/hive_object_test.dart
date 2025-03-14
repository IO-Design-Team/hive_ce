import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import 'integration.dart';

class _TestObject with HiveObjectMixin {
  String name;

  _TestObject(this.name);

  @override
  bool operator ==(Object other) => other is _TestObject && other.name == name;

  @override
  int get hashCode => runtimeType.hashCode ^ name.hashCode;
}

class _TestObjectAdapter extends TypeAdapter<_TestObject> {
  @override
  int get typeId => 0;

  @override
  _TestObject read(BinaryReader reader) {
    return _TestObject(reader.readString());
  }

  @override
  void write(BinaryWriter writer, _TestObject obj) {
    writer.writeString(obj.name);
  }
}

Future _performTest(bool lazy) async {
  final hive = await createHive(isolated: false);
  await hive.registerAdapter<_TestObject>(_TestObjectAdapter());
  var (_, box) = await openBox(lazy, isolated: false, hive: hive);

  var obj1 = _TestObject('test1');
  await box.add(obj1);
  expect(obj1.key, 0);

  var obj2 = _TestObject('test2');
  await box.put('someKey', obj2);
  expect(obj2.key, 'someKey');

  box = await hive.reopenBox(box);
  obj1 = await box.get(0) as _TestObject;
  obj2 = await box.get('someKey') as _TestObject;
  expect(obj1.name, 'test1');
  expect(obj2.name, 'test2');

  obj1.name = 'test1 updated';
  await obj1.save();
  await obj2.delete();

  box = await hive.reopenBox(box);
  final newObj1 = await box.get(0) as _TestObject;
  final newObj2 = await box.get('someKey') as _TestObject?;
  expect(newObj1.name, 'test1 updated');
  expect(newObj2, null);

  await box.close();
}

void main() {
  group(
    'use HiveObject to update and delete entries',
    () {
      test('normal box', () => _performTest(false));

      test('lazy box', () => _performTest(true));
    },
    timeout: longTimeout,
  );

  test(
    'move HiveObject between lazy boxes',
    () async {
      final hive = await createHive(isolated: false);
      await hive.registerAdapter<_TestObject>(_TestObjectAdapter());

      final (_, box1) = await openBox(true, isolated: false, hive: hive);
      final (_, box2) = await openBox(true, isolated: false, hive: hive);

      final obj = _TestObject('test');
      expect(obj.box, null);
      expect(obj.key, null);

      final key1 = await box1.add(obj);
      expect(obj.box, box1.box);
      expect(obj.key, key1);

      await obj.delete();
      expect(obj.box, null);
      expect(obj.key, null);

      final key2 = await box2.add(obj);
      expect(obj.box, box2.box);
      expect(obj.key, key2);
    },
  );
}
