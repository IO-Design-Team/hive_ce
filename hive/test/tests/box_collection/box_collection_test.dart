import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:test/test.dart';

import '../../util/is_browser/is_browser.dart';

Future<BoxCollection> _openCollection({bool withData = false}) async {
  final collection =
      await BoxCollection.open('MyFirstFluffyBox', {'cats', 'dogs'});
  addTearDown(collection.close);
  if (withData) {
    final catsBox = await collection.openBox('cats');
    await catsBox.clear();
    await catsBox.put('fluffy', {'name': 'Fluffy', 'age': 4});
    await catsBox.put('loki', {'name': 'Loki', 'age': 2});
  }
  return collection;
}

void main() {
  final hive = Hive as HiveImpl;
  hive.registerAdapter(TestAdapter());

  // web: The indexed db name identifies the collection
  // other: The box name identifies the collection
  final expectedBoxName = isBrowser ? 'cats' : 'MyFirstFluffyBox_cats';

  tearDown(() {
    hive.homePath = null;
  });

  group('BoxCollection', () {
    group('.open', () {
      test('works', () async {
        final collection = await _openCollection();
        expect(collection.name, 'MyFirstFluffyBox');
        expect(collection.boxNames, {'cats', 'dogs'});
      });
      test(
        'initializes Hive',
        () async {
          await _openCollection();
          expect(hive.homePath, isNotNull);
        },
        skip: isBrowser,
      );
      test('does not reinitialize Hive', () async {
        hive.init('MYPATH');
        await _openCollection();
        expect(hive.homePath, 'MYPATH');
      });
    });
    test('.openBox', () async {
      final collection = await _openCollection();
      try {
        await collection.openBox('rabbits');
        throw Exception('BoxCollection.openBox did not throw');
      } catch (e) {
        // The test passed
      }
      final box1 = await collection.openBox('cats');
      expect(box1.name, expectedBoxName);
    });

    test('.transaction', () async {
      final collection = await _openCollection();
      final catsBox = await collection.openBox('cats');
      await collection.transaction(() async {
        await catsBox.put('fluffy', {'name': 'Fluffy', 'age': 4});
        await catsBox.put('loki', {'name': 'Loki', 'age': 2});
      });
      expect(await catsBox.get('fluffy'), {'name': 'Fluffy', 'age': 4});
      expect(await catsBox.get('loki'), {'name': 'Loki', 'age': 2});
    });
  });

  group('CollectionBox', () {
    test('.name', () async {
      final collection = await _openCollection();
      final box = await collection.openBox('cats');
      expect(box.name, expectedBoxName);
    });

    test('.boxCollection', () async {
      final collection = await _openCollection();
      final box = await collection.openBox('cats');
      expect(box.boxCollection, collection);
    });

    test('.getAllKeys()', () async {
      final collection = await _openCollection(withData: true);
      final box = await collection.openBox('cats');
      final keys = await box.getAllKeys();
      expect(keys, ['fluffy', 'loki']);
    });

    test('.getAllValues()', () async {
      final collection = await _openCollection(withData: true);
      final box = await collection.openBox('cats');
      final values = await box.getAllValues();
      expect(values, {
        'fluffy': {'name': 'Fluffy', 'age': 4},
        'loki': {'name': 'Loki', 'age': 2},
      });
    });

    test('.get()', () async {
      final collection = await _openCollection(withData: true);
      final box = await collection.openBox('cats');
      expect(await box.get('fluffy'), {'name': 'Fluffy', 'age': 4});
    });

    test('.getAll()', () async {
      final collection = await _openCollection(withData: true);
      final box = await collection.openBox('cats');
      final values = await box.getAll(['fluffy', 'loki']);
      expect(values, [
        {'name': 'Fluffy', 'age': 4},
        {'name': 'Loki', 'age': 2},
      ]);
    });

    test('.put()', () async {
      final collection = await _openCollection();
      final box = await collection.openBox('cats');
      await box.put('fluffy', {'name': 'Fluffy', 'age': 4});
      expect(await box.get('fluffy'), {'name': 'Fluffy', 'age': 4});
    });

    test('.delete()', () async {
      final collection = await _openCollection(withData: true);
      final box = await collection.openBox('cats');
      await box.delete('fluffy');
      expect(await box.get('fluffy'), null);
    });

    test('.deleteAll()', () async {
      final collection = await _openCollection(withData: true);
      final box = await collection.openBox('cats');
      await box.deleteAll(['fluffy', 'loki']);
      expect(await box.getAllKeys(), []);
    });

    test('.clear()', () async {
      final collection = await _openCollection(withData: true);
      final box = await collection.openBox('cats');
      await box.clear();
      expect(await box.getAllKeys(), []);
    });

    test('json', () async {
      final collection = await _openCollection();
      final box = await collection.openBox('cats', fromJson: Test.fromJson);
      await box.put('json_test', testObject);
      expect(await box.get('json_test'), testObject);
    });
  });
}

const testObject = Test(a: 1, b: 'test');

class Test {
  final int a;
  final String b;

  const Test({required this.a, required this.b});

  factory Test.fromJson(Map<String, dynamic> json) =>
      Test(a: json['a'], b: json['b']);
  Map<String, dynamic> toJson() => {'a': a, 'b': b};
}

class TestAdapter extends TypeAdapter<Test> {
  @override
  final int typeId = 0;

  @override
  Test read(BinaryReader reader) => testObject;

  @override
  void write(BinaryWriter writer, Test obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.a)
      ..writeByte(1)
      ..write(obj.b);
  }
}
