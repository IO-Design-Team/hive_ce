import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  void expectTrx(Iterable<KeyTransaction> i1, Iterable<KeyTransaction> i2) {
    expect(i1.length, i2.length);
    final l1 = i1.toList();
    final l2 = i2.toList();
    for (var i = 0; i < i1.length; i++) {
      expect(l1[i].added, l2[i].added);
      expect(l1[i].deleted, l2[i].deleted);
    }
  }

  group('Keystore', () {
    test('.length returns the number of frames in the store', () {
      final keystore = Keystore.debug(frames: [Frame('a', 1), Frame(1, 'a')]);
      expect(keystore.length, 2);
      expect(Keystore.debug().length, 0);
    });

    test('.autoIncrement() updates auto increment value', () {
      final keystore = Keystore.debug();
      expect(keystore.autoIncrement(), 0);
      expect(keystore.autoIncrement(), 1);
      expect(keystore.autoIncrement(), 2);

      keystore.updateAutoIncrement(5);
      expect(keystore.autoIncrement(), 6);
      expect(keystore.autoIncrement(), 7);

      keystore.updateAutoIncrement(7);
      expect(keystore.autoIncrement(), 8);
      expect(keystore.autoIncrement(), 9);
    });

    group('.updateAutoIncrement()', () {
      test('increases auto increment value if given key is bigger', () {
        final keystore = Keystore.debug();
        expect(keystore.autoIncrement(), 0);
        keystore.updateAutoIncrement(5);
        expect(keystore.autoIncrement(), 6);
      });

      test('does nothing if given key is lower', () {
        final keystore = Keystore.debug();

        keystore.updateAutoIncrement(20);
        expect(keystore.autoIncrement(), 21);

        keystore.updateAutoIncrement(20);
        expect(keystore.autoIncrement(), 22);
      });
    });

    test('.containsKey() returns whether store has key', () {
      final keystore = Keystore.debug(frames: [Frame('key1', null)]);

      expect(keystore.containsKey('key1'), true);
      expect(keystore.containsKey('key2'), false);
    });

    group('.keyAt()', () {
      test('returns the key at the given index', () {
        final keystore = Keystore.debug(
          frames: [
            Frame('key1', null),
            Frame(2, null),
            Frame(0, null),
            Frame('0', null),
          ],
        );

        expect(keystore.keyAt(0), 0);
        expect(keystore.keyAt(1), 2);
        expect(keystore.keyAt(2), '0');
        expect(keystore.keyAt(3), 'key1');
      });

      test('throws RangeError if the index does not exist', () {
        final keystore = Keystore.debug(frames: [Frame('key1', null)]);

        expect(() => keystore.keyAt(1), throwsRangeError);
        expect(() => keystore.keyAt(999), throwsRangeError);
        expect(() => Keystore.debug().keyAt(0), throwsRangeError);
      });
    });

    group('.get()', () {
      test('returns the frame of the given key', () {
        final keystore = Keystore.debug(
          frames: [
            Frame('key1', 'value1'),
            Frame(1, 'value2'),
          ],
        );

        expect(keystore.get('key1'), Frame('key1', 'value1'));
        expect(keystore.get(1), Frame(1, 'value2'));
      });

      test('returns null if there is no such key', () {
        final keystore = Keystore.debug(frames: [Frame('key', 'value')]);
        expect(keystore.get('key2'), null);
        expect(Keystore.debug().get('someKey'), null);
      });
    });

    group('.getAt()', () {
      test('returns the frame at the given index', () {
        final keystore = Keystore.debug(
          frames: [
            Frame('key1', 'value1'),
            Frame(4, 'value2'),
          ],
        );

        expect(keystore.getAt(0), Frame(4, 'value2'));
        expect(keystore.getAt(1), Frame('key1', 'value1'));
      });

      test('throws RangeError index does not exist', () {
        final keystore = Keystore.debug(frames: [Frame('key1', 'value1')]);
        expect(() => keystore.getAt(1), throwsRangeError);
        expect(() => Keystore.debug().getAt(0), throwsRangeError);
      });
    });

    test('.getKeys() returns the keys in the correct order', () {
      final keystore = Keystore.debug(
        frames: [
          Frame('key1', null),
          Frame(2, null),
          Frame(0, null),
          Frame('0', null),
        ],
      );

      expect(keystore.getKeys(), [0, 2, '0', 'key1']);
    });

    test('.getValues() returns the values in the order of their keys', () {
      final keystore = Keystore.debug(
        frames: [
          Frame('key1', 4),
          Frame(2, 2),
          Frame(0, null),
          Frame('0', 3),
        ],
      );

      expect(keystore.getValues(), [null, 2, 3, 4]);
    });

    group('.getValuesBetween()', () {
      Keystore keystore() => Keystore.debug(
            frames: [
              Frame('key1', 4),
              Frame(2, 2),
              Frame(0, null),
              Frame('0', 3),
            ],
          );

      test('startKey and endKey specified', () {
        expect(keystore().getValuesBetween(2, '0'), [2, 3]);
      });

      test('only startKey specified', () {
        expect(keystore().getValuesBetween(2, null), [2, 3, 4]);
      });

      test('only endKey specified', () {
        expect(keystore().getValuesBetween(null, '0'), [null, 2, 3]);
      });

      test('endKey before startKey', () {
        expect(keystore().getValuesBetween(2, 0), [2, 3, 4]);
      });
    });

    group('.insert()', () {
      group('add', () {
        test('updates auto increment', () {
          final keystore = Keystore.debug();
          expect(keystore.autoIncrement(), 0);

          keystore.insert(Frame(123, 'val'));
          expect(keystore.autoIncrement(), 124);

          keystore.insert(Frame('500', 'val'));
          expect(keystore.autoIncrement(), 125);
        });

        test('initializes HiveObject', () {
          final box = MockBox();
          final keystore = Keystore.debug(box: box);

          final hiveObject = TestHiveObject();
          keystore.insert(Frame('key', hiveObject));

          expect(hiveObject.key, 'key');
          expect(hiveObject.box, box);
        });

        test('adds frame to store', () {
          final keystore = Keystore.debug();
          keystore.insert(Frame('key2', 'val2'));
          keystore.insert(Frame('key1', 'val1'));

          expect(
            keystore.frames,
            [Frame('key1', 'val1'), Frame('key2', 'val2')],
          );
        });

        test('returns overridden Frame', () {
          final keystore = Keystore.debug();

          final frame = Frame('key', 'val');
          expect(keystore.insert(frame), null);
          expect(keystore.insert(Frame('key', 'val2')), frame);
        });

        test('unloads previous HiveObject', () {
          final box = MockBox();
          final keystore = Keystore.debug(box: box);

          final hiveObject = TestHiveObject();
          keystore.insert(Frame('key', hiveObject));
          keystore.insert(Frame('key', TestHiveObject()));

          expect(hiveObject.key, null);
          expect(hiveObject.box, null);
        });

        test('does not unload HiveObject if it is the same instance', () {
          final box = MockBox();
          final keystore = Keystore.debug(box: box);

          final hiveObject = TestHiveObject();
          keystore.insert(Frame('key', hiveObject));
          keystore.insert(Frame('key', hiveObject));

          expect(hiveObject.key, 'key');
          expect(hiveObject.box, box);
        });

        test('increases deletedEntries', () {
          final keystore = Keystore.debug();
          expect(keystore.deletedEntries, 0);

          keystore.insert(Frame('key1', 'val1'));
          expect(keystore.deletedEntries, 0);

          keystore.insert(Frame('key1', 'val2'));
          expect(keystore.deletedEntries, 1);
        });

        test('broadcasts change event', () {
          final notifier = MockChangeNotifier();
          final keystore = Keystore.debug(notifier: notifier);

          keystore.insert(Frame('key1', 'val1'));
          verify(() => notifier.notify(Frame('key1', 'val1')));

          keystore.insert(Frame('key1', 'val2'));
          verify(
            () => notifier.notify(Frame('key1', 'val2'), deletedValue: 'val1'),
          );
        });
      });

      group('delete', () {
        test('deletes frame from store', () {
          final keystore = Keystore.debug(
            frames: [
              Frame('key2', 'val2'),
              Frame('key1', 'val1'),
            ],
          );

          keystore.insert(Frame.deleted('key2'));
          expect(keystore.frames, [Frame('key1', 'val1')]);
        });

        test('returns deleted Frame', () {
          final frame = Frame('key', 'val');
          final keystore = Keystore.debug(frames: [frame]);

          expect(keystore.insert(Frame.deleted('key')), frame);
          expect(keystore.insert(Frame.deleted('key')), null);
        });

        test('unloads deleted HiveObject', () {
          final box = MockBox();
          final hiveObject = TestHiveObject();
          final keystore =
              Keystore.debug(frames: [Frame('key', hiveObject)], box: box);

          keystore.insert(Frame.deleted('key'));
          expect(hiveObject.key, null);
          expect(hiveObject.box, null);
        });

        test('increases deletedEntries', () {
          final keystore = Keystore.debug(frames: [Frame('key1', 'val1')]);
          expect(keystore.deletedEntries, 0);

          keystore.insert(Frame.deleted('key1'));
          expect(keystore.deletedEntries, 1);
        });

        test('broadcasts change event', () {
          final notifier = MockChangeNotifier();
          final keystore = Keystore.debug(
            frames: [Frame('key1', 'val1')],
            notifier: notifier,
          );

          reset(notifier);

          keystore.insert(Frame.deleted('key1'));
          verify(
            () => notifier.notify(Frame.deleted('key1'), deletedValue: 'val1'),
          );

          keystore.insert(Frame.deleted('key1'));
          verifyNoMoreInteractions(notifier);
        });
      });
    });

    group('.beginTransaction()', () {
      test('adding new frames', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(notifier: notifier);

        final created = keystore.beginTransaction([
          Frame('key1', 'val1'),
          Frame('key2', 'val2'),
        ]);

        expect(created, true);
        expect(keystore.transactions.first.added, ['key1', 'key2']);
        expect(keystore.frames, [Frame('key1', 'val1'), Frame('key2', 'val2')]);
        verify(() => notifier.notify(Frame('key1', 'val1')));
        verify(() => notifier.notify(Frame('key2', 'val2')));
      });

      test('overriding existing keys', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(
          frames: [Frame('key1', 'val1')],
          notifier: notifier,
        );
        reset(notifier);

        final created = keystore.beginTransaction([
          Frame('key1', 'val2'),
          Frame('key2', 'val3'),
        ]);

        expect(created, true);
        expect(keystore.transactions.first.deleted, {
          'key1': Frame('key1', 'val1'),
        });
        expect(keystore.frames, [Frame('key1', 'val2'), Frame('key2', 'val3')]);
        verify(
          () => notifier.notify(Frame('key1', 'val2'), deletedValue: 'val1'),
        );
        verify(() => notifier.notify(Frame('key2', 'val3')));
      });

      test('empty transaction', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(
          frames: [Frame('key1', 'val1')],
          notifier: notifier,
        );
        reset(notifier);

        final created = keystore.beginTransaction([]);

        expect(created, false);
        expect(keystore.frames, [Frame('key1', 'val1')]);
        verifyZeroInteractions(notifier);
      });

      test('deleting frames', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(
          frames: [
            Frame('key1', 'val1'),
            Frame('key2', 'val2'),
          ],
          notifier: notifier,
        );
        reset(notifier);

        final created = keystore.beginTransaction([
          Frame.deleted('key1'),
          Frame.deleted('key3'),
        ]);

        expect(created, true);
        expect(keystore.transactions.first.deleted, {
          'key1': Frame('key1', 'val1'),
        });
        expect(keystore.frames, [Frame('key2', 'val2')]);
        verify(
          () => notifier.notify(Frame.deleted('key1'), deletedValue: 'val1'),
        );
      });
    });

    group('.commitTransaction()', () {
      test('removes the oldest transaction', () {
        final keystore = Keystore.debug();
        keystore.beginTransaction([Frame('key1', 'val1')]);
        keystore.beginTransaction([Frame('key2', 'val2')]);

        expectTrx(keystore.transactions, [
          KeyTransaction()..added.add('key1'),
          KeyTransaction()..added.add('key2'),
        ]);

        keystore.commitTransaction();
        expectTrx(keystore.transactions, [KeyTransaction()..added.add('key2')]);
      });

      test('fails if there are no pending transactions', () {
        final keystore = Keystore.debug();
        expect(keystore.commitTransaction, throwsStateError);
      });
    });

    group('.cancelTransaction()', () {
      test('add', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(notifier: notifier);
        keystore.beginTransaction([Frame('key', 'val1')]);
        keystore.beginTransaction([Frame('otherKey', 'otherVal')]);
        reset(notifier);

        keystore.cancelTransaction();
        expect(keystore.frames, [Frame('otherKey', 'otherVal')]);
        expectTrx(
          keystore.transactions,
          [KeyTransaction()..added.add('otherKey')],
        );
        verify(
          () => notifier.notify(Frame.deleted('key'), deletedValue: 'val1'),
        );
      });

      test('add then override', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(notifier: notifier);
        keystore.beginTransaction([Frame('key', 'val1')]);
        keystore.beginTransaction([Frame('key', 'val2')]);
        reset(notifier);

        keystore.cancelTransaction();
        expect(keystore.frames, [Frame('key', 'val2')]);
        expectTrx(keystore.transactions, [KeyTransaction()..added.add('key')]);
        verifyZeroInteractions(notifier);
      });

      test('add then delete', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(notifier: notifier);
        keystore.beginTransaction([Frame('key', 'val1')]);
        keystore.beginTransaction([
          Frame('otherKey', 'otherVal'),
          Frame.deleted('key'),
        ]);
        keystore.beginTransaction([
          Frame('key', 'val2'),
        ]);
        reset(notifier);

        keystore.cancelTransaction();
        expect(keystore.frames, [
          Frame('key', 'val2'),
          Frame('otherKey', 'otherVal'),
        ]);
        expectTrx(keystore.transactions, [
          KeyTransaction()..added.add('otherKey'),
          KeyTransaction()..added.add('key'),
        ]);
        verifyZeroInteractions(notifier);
      });

      test('override', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(
          frames: [Frame('key', 'val1')],
          notifier: notifier,
        );
        keystore.beginTransaction([Frame('key', 'val2')]);
        reset(notifier);

        keystore.cancelTransaction();
        expect(keystore.frames, [Frame('key', 'val1')]);
        expectTrx(keystore.transactions, []);
        verify(() => notifier.notify(Frame('key', 'val1')));
      });

      test('override then add', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(
          frames: [Frame('key', 'val1')],
          notifier: notifier,
        );
        keystore.beginTransaction([Frame('key', 'val2')]);
        keystore.beginTransaction([Frame('key', 'val3')]);
        reset(notifier);

        keystore.cancelTransaction();
        expect(keystore.frames, [Frame('key', 'val3')]);
        expectTrx(keystore.transactions, [
          KeyTransaction()
            ..added.add('key')
            ..deleted['key'] = Frame('key', 'val1'),
        ]);
        verifyZeroInteractions(notifier);
      });

      test('override then delete', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(
          frames: [Frame('key', 'val1')],
          notifier: notifier,
        );
        keystore.beginTransaction([Frame('key', 'val2')]);
        keystore.beginTransaction([Frame.deleted('key')]);
        reset(notifier);

        keystore.cancelTransaction();
        expect(keystore.frames, []);
        expectTrx(keystore.transactions, [
          KeyTransaction()..deleted['key'] = Frame('key', 'val1'),
        ]);
        verifyZeroInteractions(notifier);
      });

      test('delete', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(
          frames: [Frame('key', 'val1')],
          notifier: notifier,
        );
        keystore.beginTransaction([Frame.deleted('key')]);
        reset(notifier);

        keystore.cancelTransaction();
        expect(keystore.frames, [Frame('key', 'val1')]);
        expectTrx(keystore.transactions, []);
        verify(() => notifier.notify(Frame('key', 'val1')));
      });

      test('delete then add', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(frames: [Frame('key', 'val1')]);
        keystore.beginTransaction([Frame.deleted('key')]);
        keystore.beginTransaction([Frame('key', 'val2')]);
        reset(notifier);

        keystore.cancelTransaction();
        expect(keystore.frames, [Frame('key', 'val2')]);
        expectTrx(keystore.transactions, [
          KeyTransaction()
            ..added.add('key')
            ..deleted['key'] = Frame('key', 'val1'),
        ]);
        verifyZeroInteractions(notifier);
      });
    });

    group('.clear()', () {
      test('clears store', () {
        final keystore = Keystore.debug(
          frames: [
            Frame('key1', 'val1'),
            Frame('key2', 'val2'),
          ],
        );
        keystore.clear();
        expect(keystore.frames, []);
      });

      test('unloads HiveObjects', () {
        final hiveObject = TestHiveObject();
        final box = MockBox();
        final keystore = Keystore.debug(
          frames: [
            Frame('key1', 'val1'),
            Frame('key2', hiveObject),
          ],
          box: box,
        );
        expect(hiveObject.key, 'key2');
        expect(hiveObject.box, box);

        keystore.clear();
        expect(hiveObject.key, null);
        expect(hiveObject.box, null);
      });

      test('resets deleted entries', () {
        final keystore = Keystore.debug(
          frames: [
            Frame('key1', 'val1'),
            Frame('key2', 'val2'),
          ],
        );

        keystore.insert(Frame.deleted('key1'));
        expect(keystore.deletedEntries, 1);

        keystore.clear();
        expect(keystore.deletedEntries, 0);
      });

      test('resets auto increment counter', () {
        final keystore = Keystore.debug();
        expect(keystore.autoIncrement(), 0);
        expect(keystore.autoIncrement(), 1);

        keystore.clear();
        expect(keystore.autoIncrement(), 0);
      });

      test('broadcasts change event', () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(
          frames: [Frame('key1', 'val1'), Frame('key2', 'val2')],
          notifier: notifier,
        );
        reset(notifier);

        keystore.clear();
        verify(
          () => notifier.notify(Frame.deleted('key1'), deletedValue: 'val1'),
        );
        verify(
          () => notifier.notify(Frame.deleted('key2'), deletedValue: 'val2'),
        );
      });
    });

    group('packed lazy storage', () {
      test('inserts, reads, updates, deletes, and clears packed lazy frames',
          () {
        final notifier = MockChangeNotifier();
        final keystore = Keystore.debug(notifier: notifier);

        // 5000000000 exceeds 32-bit signed int; verifies Float64List 53-bit offsets.
        expect(
          keystore.insert(
            Frame('k2', 'v2', offset: 5000000000, length: 64),
            lazy: true,
          ),
          null,
        );
        expect(
          keystore.insert(
            Frame.lazy(1, offset: 10, length: null),
            notify: false,
          ),
          null,
        );
        expect(
          keystore.insert(
            Frame(3, 'v3', offset: 100, length: 32),
            lazy: true,
          ),
          null,
        );

        expect(keystore.length, 3);
        expect(keystore.containsKey('k2'), true);
        expect(keystore.containsKey('missing'), false);
        expect(keystore.autoIncrement(), 4);
        expect(keystore.keyAt(0), 1);
        expect(keystore.keyAt(1), 3);
        expect(keystore.keyAt(2), 'k2');

        final f0 = keystore.getAt(0)!;
        expect(f0.lazy, true);
        expect(f0.key, 1);
        expect(f0.offset, 10);
        expect(f0.length, null);

        final f2 = keystore.get('k2')!;
        expect(f2.lazy, true);
        expect(f2.key, 'k2');
        expect(f2.offset, 5000000000);
        expect(f2.length, 64);

        expect(keystore.getKeys(), [1, 3, 'k2']);
        expect(keystore.getValues(), [null, null, null]);
        expect(keystore.getValuesBetween(3, 'k2'), [null, null]);
        expect(keystore.frames.length, 3);

        // Overwrite existing lazy key.
        final prev = keystore.insert(
          Frame('k2', 'v2-new', offset: 6000000000, length: 96),
          lazy: true,
        )!;
        expect(prev.key, 'k2');
        expect(prev.lazy, true);
        expect(prev.offset, 5000000000);
        expect(prev.length, 64);
        expect(keystore.deletedEntries, 1);
        expect(keystore.get('k2')!.offset, 6000000000);
        expect(keystore.get('k2')!.length, 96);
        verify(
          () => notifier.notify(
            Frame('k2', 'v2-new', offset: 6000000000, length: 96),
          ),
        );

        // Update packed offsets (e.g. after compaction).
        keystore.updatePackedOffsets([
          Frame.lazy(1, offset: 0, length: 12),
          Frame.lazy('k2', offset: 12, length: 96),
          Frame.lazy('not-present', offset: 999, length: 10),
        ]);
        expect(keystore.length, 3);
        expect(keystore.get(1)!.offset, 0);
        expect(keystore.get(1)!.length, 12);
        expect(keystore.get('k2')!.offset, 12);
        expect(keystore.get('k2')!.length, 96);
        expect(keystore.get('not-present'), null);

        // Delete lazy key.
        reset(notifier);
        final deleted = keystore.insert(Frame.deleted(3))!;
        expect(deleted.key, 3);
        expect(deleted.lazy, true);
        expect(deleted.offset, 100);
        expect(deleted.length, 32);
        expect(keystore.length, 2);
        expect(keystore.deletedEntries, 2);
        expect(keystore.containsKey(3), false);
        expect(keystore.insert(Frame.deleted(3)), null);
        verify(() => notifier.notify(Frame.deleted(3)));

        // Clear packed lazy store.
        reset(notifier);
        expect(keystore.clear(), 2);
        expect(keystore.length, 0);
        expect(keystore.deletedEntries, 0);
        expect(keystore.autoIncrement(), 0);
        expect(keystore.frames, isEmpty);
        verify(() => notifier.notify(Frame.deleted(1)));
        verify(() => notifier.notify(Frame.deleted('k2')));
      });

      test('updatePackedOffsets is a no-op on eager keystore', () {
        final keystore = Keystore.debug(frames: [Frame('a', 1, offset: 10)]);
        keystore.updatePackedOffsets([Frame('a', 1, offset: 99, length: 10)]);
        expect(keystore.get('a')!.offset, 10);
      });

      test('promotes packed lazy entries if eager frame is inserted', () {
        final keystore = Keystore.debug();
        keystore.insert(Frame.lazy('a', offset: 12, length: 34));
        keystore.insert(Frame('b', 'eager'));

        expect(keystore.length, 2);
        expect(keystore.get('a')!.lazy, true);
        expect(keystore.get('a')!.offset, 12);
        expect(keystore.get('a')!.length, 34);
        expect(keystore.get('b'), Frame('b', 'eager'));
      });
    });
  });
}
