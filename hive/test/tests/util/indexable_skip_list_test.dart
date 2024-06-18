import 'dart:math';

import 'package:hive_ce/src/util/indexable_skip_list.dart';
import 'package:test/test.dart';

void main() {
  group('IndexableSkipList', () {
    List<int> getRandomList() {
      final rand = Random();
      final data = List.generate(1000, (i) => i);
      data.addAll(List.generate(500, (i) => rand.nextInt(1000)));
      data.addAll(List.generate(250, (i) => 1000 - i % 50));
      data.addAll(List.generate(250, (i) => i));
      data.shuffle();
      return data;
    }

    void checkList(IndexableSkipList list, List<Comparable> keys) {
      final sortedKeys = keys.toSet().toList()..sort();
      expect(list.keys, sortedKeys);
      for (var n = 0; n < sortedKeys.length; n++) {
        final key = sortedKeys[n];
        expect(list.get(key), '$key');
        expect(list.getAt(n), '$key');
      }
    }

    test('.insert() puts value at the correct position', () {
      final list = IndexableSkipList(Comparable.compare);
      final data = getRandomList();

      for (var i = 0; i < data.length; i++) {
        list.insert(data[i], '${data[i]}');
        final alreadyAdded = data.sublist(0, i + 1);
        checkList(list, alreadyAdded);
      }
    });

    test('.delete() removes key', () {
      final list = IndexableSkipList(Comparable.compare);
      final data = getRandomList();
      for (final key in data) {
        list.insert(key, '$key');
      }

      final keys = data.toSet().toList()..shuffle();
      while (keys.isNotEmpty) {
        final key = keys.first;
        expect(list.delete(key), '$key');
        keys.remove(key);
        checkList(list, keys);
      }
    });
  });
}
