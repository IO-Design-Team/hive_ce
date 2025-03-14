import 'dart:typed_data';

import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/object/hive_list_impl.dart';
import 'package:hive_ce/src/object/hive_object.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../integration/integration.dart';
import '../common.dart';
import '../mocks.dart';

HiveObject _getHiveObject(String key, MockBox box) {
  final hiveObject = TestHiveObject();
  hiveObject.init(key, box);
  when(
    () => box.get(
      key,
      defaultValue: captureAny(that: isNotNull, named: 'defaultValue'),
    ),
  ).thenReturn(hiveObject);
  when(() => box.get(key)).thenReturn(hiveObject);
  return hiveObject;
}

MockBox _mockBox() {
  final box = MockBox();
  // The HiveListImpl constructor sets the boxName property to box.name,
  // therefore we need to return an valid String on sound null safety.
  when(() => box.name).thenReturn('testBox');
  return box;
}

void main() {
  group('HiveListImpl', () {
    test('HiveListImpl()', () {
      final box = _mockBox();

      final item1 = _getHiveObject('item1', box);
      final item2 = _getHiveObject('item2', box);
      final list = HiveListImpl(box, objects: [item1, item2, item1]);

      expect(item1.debugHiveLists, {list: 2});
      expect(item2.debugHiveLists, {list: 1});
    });

    test('HiveListImpl.lazy()', () {
      final list = HiveListImpl.lazy('testBox', ['key1', 'key2']);
      expect(list.boxName, 'testBox');
      expect(list.keys, ['key1', 'key2']);
    });

    group('.box', () {
      test('throws HiveError if box is not open', () async {
        final hive = await createHive(type: TestType.normal);
        final hiveList = HiveListImpl.lazy('someBox', [])
          ..debugHive = hive.hive as HiveImpl;
        expect(() => hiveList.box, throwsHiveError('you have to open the box'));
      });

      test('returns the box', () async {
        final hive = await createHive(type: TestType.normal);
        final box = await hive.openBox<int>('someBox', bytes: Uint8List(0));
        final hiveList = HiveListImpl.lazy('someBox', [])
          ..debugHive = hive.hive as HiveImpl;
        expect(hiveList.box, box.box);
      });
    });

    group('.delegate', () {
      test('throws exception if HiveList is disposed', () {
        final list = HiveListImpl.lazy('box', []);
        list.dispose();
        expect(() => list.delegate, throwsHiveError('already been disposed'));
      });

      test('removes correct elements if invalidated', () {
        final box = _mockBox();
        final item1 = _getHiveObject('item1', box);
        final item2 = _getHiveObject('item2', box);
        final list = HiveListImpl(box, objects: [item1, item2, item1]);

        item1.debugHiveLists.clear();
        expect(list.delegate, [item1, item2, item1]);
        list.invalidate();
        expect(list.delegate, [item2]);
      });

      test('creates delegate and links HiveList if delegate == null', () {
        final hive = MockHiveImpl();
        final box = _mockBox();
        when(() => box.containsKey('item1')).thenReturn(true);
        when(() => box.containsKey('item2')).thenReturn(true);
        when(() => box.containsKey('none')).thenReturn(false);
        when(() => hive.getBoxWithoutCheckInternal('box')).thenReturn(box);

        final item1 = _getHiveObject('item1', box);
        final item2 = _getHiveObject('item2', box);

        final list =
            HiveListImpl.lazy('box', ['item1', 'none', 'item2', 'item1'])
              ..debugHive = hive;
        expect(list.delegate, [item1, item2, item1]);
        expect(item1.debugHiveLists, {list: 2});
        expect(item2.debugHiveLists, {list: 1});
      });
    });

    group('.dispose()', () {
      test('unlinks remote HiveObjects if delegate exists', () {
        final box = _mockBox();
        final item1 = _getHiveObject('item1', box);
        final item2 = _getHiveObject('item2', box);

        final list = HiveListImpl(box, objects: [item1, item2, item1]);
        list.dispose();

        expect(item1.debugHiveLists, {});
        expect(item2.debugHiveLists, {});
      });
    });

    test('set length', () {
      final box = _mockBox();
      final item1 = _getHiveObject('item1', box);
      final item2 = _getHiveObject('item2', box);

      final list = HiveListImpl(box, objects: [item1, item2]);
      list.length = 1;

      expect(item2.debugHiveLists, {});
      expect(list, [item1]);
    });

    group('operator []=', () {
      test('sets key at index', () {
        final box = _mockBox();
        final oldItem = _getHiveObject('old', box);
        final newItem = _getHiveObject('new', box);

        final list = HiveListImpl(box, objects: [oldItem]);
        list[0] = newItem;

        expect(oldItem.debugHiveLists, {});
        expect(newItem.debugHiveLists, {list: 1});
        expect(list, [newItem]);
      });

      test('throws HiveError if HiveObject is not valid', () {
        final box = _mockBox();
        final oldItem = _getHiveObject('old', box);
        final newItem = _getHiveObject('new', MockBox());

        final list = HiveListImpl(box, objects: [oldItem]);
        expect(() => list[0] = newItem, throwsHiveError());
      });
    });

    group('.add()', () {
      test('adds key', () {
        final box = _mockBox();
        final item1 = _getHiveObject('item1', box);
        final item2 = _getHiveObject('item2', box);

        final list = HiveListImpl(box, objects: [item1]);
        list.add(item2);

        expect(item2.debugHiveLists, {list: 1});
        expect(list, [item1, item2]);
      });

      test('throws HiveError if HiveObject is not valid', () {
        final box = _mockBox();
        final item = _getHiveObject('item', MockBox());
        final list = HiveListImpl(box);
        expect(() => list.add(item), throwsHiveError('needs to be in the box'));
      });
    });

    group('.addAll()', () {
      test('adds keys', () {
        final box = _mockBox();
        final item1 = _getHiveObject('item1', box);
        final item2 = _getHiveObject('item2', box);

        final list = HiveListImpl(box, objects: [item1]);
        list.addAll([item2, item2]);

        expect(item2.debugHiveLists, {list: 2});
        expect(list, [item1, item2, item2]);
      });

      test('throws HiveError if HiveObject is not valid', () {
        final box = _mockBox();
        final item = _getHiveObject('item', MockBox());

        final list = HiveListImpl(box);
        expect(
          () => list.addAll([item]),
          throwsHiveError('needs to be in the box'),
        );
      });
    });
  });
}
