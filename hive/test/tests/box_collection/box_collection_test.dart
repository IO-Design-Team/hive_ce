import 'package:hive/src/box_collection/box_collection.dart';
import 'package:test/test.dart';

Future<BoxCollection> _openCollection({bool withData = false}) async {
  final collection =
      await BoxCollection.open('MyFirstFluffyBox', {'cats', 'dogs'});
  if (withData) {
    final catsBox = await collection.openBox('cats');
    await catsBox.put('fluffy', {'name': 'Fluffy', 'age': 4});
    await catsBox.put('loki', {'name': 'Loki', 'age': 2});
  }
  return collection;
}

void main() {
  group('BoxCollection', () {
    test('.open', () async {
      final collection = await _openCollection();
      expect(collection.name, 'MyFirstFluffyBox');
      expect(collection.boxNames, {'cats', 'dogs'});
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
      expect(box1.name, 'MyFirstFluffyBox_cats');
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
      expect(box.name, 'MyFirstFluffyBox_cats');
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
        'loki': {'name': 'Loki', 'age': 2}
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
        {'name': 'Loki', 'age': 2}
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
  });
}
