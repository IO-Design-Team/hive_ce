import 'package:hive_ce/src/object/hive_object.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../common.dart';
import '../mocks.dart';

void main() {
  group('HiveObject', () {
    group('.init()', () {
      test('adds key and box to HiveObject', () {
        final obj = TestHiveObject();
        final box = MockBox();

        obj.init('someKey', box);

        expect(obj.key, 'someKey');
        expect(obj.box, box);
      });

      test('does nothing if old key and box are equal to new key and box', () {
        final obj = TestHiveObject();
        final box = MockBox();

        obj.init('someKey', box);
        obj.init('someKey', box);

        expect(obj.key, 'someKey');
        expect(obj.box, box);
      });

      test('throws exception if object is already in a different box', () {
        final obj = TestHiveObject();
        final box1 = MockBox();
        final box2 = MockBox();

        obj.init('someKey', box1);
        expect(() => obj.init('someKey', box2),
            throwsHiveError('two different boxes'),);
      });

      test('throws exception if object has already different key', () {
        final obj = TestHiveObject();
        final box = MockBox();

        obj.init('key1', box);
        expect(
            () => obj.init('key2', box), throwsHiveError('two different keys'),);
      });
    });

    group('.dispose()', () {
      test('removes key and box', () {
        final obj = TestHiveObject();
        final box = MockBox();

        obj.init('key', box);
        obj.dispose();

        expect(obj.key, null);
        expect(obj.box, null);
      });

      test('notifies remote HiveLists', () {
        final obj = TestHiveObject();
        final box = MockBox();
        obj.init('key', box);

        final list = MockHiveListImpl();
        obj.linkHiveList(list);
        obj.dispose();

        verify(list.invalidate);
      });
    });

    test('.linkHiveList()', () {
      final box = MockBox();
      final obj = TestHiveObject();
      obj.init('key', box);
      final hiveList = MockHiveListImpl();

      obj.linkHiveList(hiveList);
      expect(obj.debugHiveLists, {hiveList: 1});
      obj.linkHiveList(hiveList);
      expect(obj.debugHiveLists, {hiveList: 2});
    });

    test('.unlinkHiveList()', () {
      final box = MockBox();
      final obj = TestHiveObject();
      obj.init('key', box);
      final hiveList = MockHiveListImpl();

      obj.linkHiveList(hiveList);
      obj.linkHiveList(hiveList);
      expect(obj.debugHiveLists, {hiveList: 2});

      obj.unlinkHiveList(hiveList);
      expect(obj.debugHiveLists, {hiveList: 1});
      obj.unlinkHiveList(hiveList);
      expect(obj.debugHiveLists, {});
    });

    group('.save()', () {
      test('updates object in box', () {
        final obj = TestHiveObject();
        final box = MockBox();
        returnFutureVoid(when(() => box.put('key', obj)));

        obj.init('key', box);
        verifyZeroInteractions(box);

        obj.save();
        verify(() => box.put('key', obj));
      });

      test('throws HiveError if object is not in a box', () async {
        final obj = TestHiveObject();
        await expectLater(obj.save, throwsHiveError('not in a box'));
      });
    });

    group('.delete()', () {
      test('removes object from box', () {
        final obj = TestHiveObject();
        final box = MockBox();
        returnFutureVoid(when(() => box.delete('key')));

        obj.init('key', box);
        verifyZeroInteractions(box);

        obj.delete();
        verify(() => box.delete('key'));
      });

      test('throws HiveError if object is not in a box', () async {
        final obj = TestHiveObject();
        await expectLater(obj.delete, throwsHiveError('not in a box'));
      });
    });

    group('.isInBox', () {
      test('returns false if box is not set', () {
        final obj = TestHiveObject();
        expect(obj.isInBox, false);
      });

      test('returns true if object is in normal box', () {
        final obj = TestHiveObject();
        final box = MockBox();
        when(() => box.lazy).thenReturn(false);
        obj.init('key', box);

        expect(obj.isInBox, true);
      });

      test('returns the result ob box.containsKey() if object is in lazy box',
          () {
        final obj = TestHiveObject();
        final box = MockBox();
        when(() => box.lazy).thenReturn(true);
        obj.init('key', box);

        when(() => box.containsKey('key')).thenReturn(true);
        expect(obj.isInBox, true);

        when(() => box.containsKey('key')).thenReturn(false);
        expect(obj.isInBox, false);
      });
    });
  });
}
