import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../common.dart';

class StreamControllerMock<T> extends Mock implements StreamController<T> {}

void main() {
  group('ChangeNotifier', () {
    test('.watch()', () async {
      final notifier = ChangeNotifier();

      final allEvents = <BoxEvent>[];
      notifier.watch().listen(allEvents.add);

      final filteredEvents = <BoxEvent>[];
      notifier.watch(key: 'key1').listen(filteredEvents.add);

      notifier.notify(Frame.deleted('key1'));
      notifier.notify(Frame('key1', 'newVal'));
      notifier.notify(Frame('key2', 'newVal2'));

      await Future.delayed(Duration(milliseconds: 1));

      expect(allEvents, [
        BoxEvent('key1', null, true),
        BoxEvent('key1', 'newVal', false),
        BoxEvent('key2', 'newVal2', false),
      ]);

      expect(filteredEvents, [
        BoxEvent('key1', null, true),
        BoxEvent('key1', 'newVal', false),
      ]);
    });

    test('close', () async {
      final controller = StreamControllerMock<BoxEvent>();
      returnFutureVoid(when(controller.close));
      final notifier = ChangeNotifier.debug(controller);

      await notifier.close();
      verify(controller.close);
    });

    test('routes per-key watchers independently', () async {
      final notifier = ChangeNotifier();

      final key1Events = <BoxEvent>[];
      final key2Events = <BoxEvent>[];
      final sub1 = notifier.watch(key: 'key1').listen(key1Events.add);
      final sub2 = notifier.watch(key: 'key2').listen(key2Events.add);
      expect(notifier.keyControllerCount, 2);

      notifier.notify(Frame('key1', 'v1'));
      notifier.notify(Frame('key2', 'v2'));
      notifier.notify(Frame('key3', 'v3'));
      notifier.notify(Frame.deleted('key1'), deletedValue: 'v1');

      await Future<void>.delayed(Duration(milliseconds: 1));

      expect(key1Events, [
        BoxEvent('key1', 'v1', false),
        BoxEvent('key1', 'v1', true),
      ]);
      expect(key2Events, [
        BoxEvent('key2', 'v2', false),
      ]);

      await sub1.cancel();
      await sub2.cancel();
      await notifier.close();
    });

    test('cleans up per-key controller on cancel and recreates on re-listen',
        () async {
      final notifier = ChangeNotifier();
      expect(notifier.keyControllerCount, 0);

      final firstEvents = <BoxEvent>[];
      final sub1 = notifier.watch(key: 'key1').listen(firstEvents.add);
      expect(notifier.keyControllerCount, 1);

      notifier.notify(Frame('key1', 'v1'));
      await Future<void>.delayed(Duration(milliseconds: 1));

      await sub1.cancel();
      expect(notifier.keyControllerCount, 0);

      notifier.notify(Frame('key1', 'ignored'));
      await Future<void>.delayed(Duration(milliseconds: 1));

      final secondEvents = <BoxEvent>[];
      final sub2 = notifier.watch(key: 'key1').listen(secondEvents.add);
      expect(notifier.keyControllerCount, 1);

      notifier.notify(Frame('key1', 'v2'));
      await Future<void>.delayed(Duration(milliseconds: 1));

      expect(firstEvents, [BoxEvent('key1', 'v1', false)]);
      expect(secondEvents, [BoxEvent('key1', 'v2', false)]);

      await sub2.cancel();
      expect(notifier.keyControllerCount, 0);
      await notifier.close();
    });

    test('supports multiple listeners on the same key', () async {
      final notifier = ChangeNotifier();

      final events1 = <BoxEvent>[];
      final events2 = <BoxEvent>[];
      final sub1 = notifier.watch(key: 'key1').listen(events1.add);
      final sub2 = notifier.watch(key: 'key1').listen(events2.add);
      expect(notifier.keyControllerCount, 1);

      notifier.notify(Frame('key1', 'v1'));
      await Future<void>.delayed(Duration(milliseconds: 1));

      expect(events1, [BoxEvent('key1', 'v1', false)]);
      expect(events2, [BoxEvent('key1', 'v1', false)]);

      await sub1.cancel();
      expect(notifier.keyControllerCount, 1);

      notifier.notify(Frame('key1', 'v2'));
      await Future<void>.delayed(Duration(milliseconds: 1));

      expect(events1, [BoxEvent('key1', 'v1', false)]);
      expect(events2, [
        BoxEvent('key1', 'v1', false),
        BoxEvent('key1', 'v2', false),
      ]);

      await sub2.cancel();
      expect(notifier.keyControllerCount, 0);
      await notifier.close();
    });

    test('delivers simultaneously to global and per-key listeners', () async {
      final notifier = ChangeNotifier();

      final globalEvents = <BoxEvent>[];
      final keyEvents = <BoxEvent>[];
      final globalSub = notifier.watch().listen(globalEvents.add);
      final keySub = notifier.watch(key: 'key1').listen(keyEvents.add);

      notifier.notify(Frame('key1', 'v1'));
      notifier.notify(Frame('key2', 'v2'));
      notifier.notify(Frame.deleted('key1'), deletedValue: 'v1');
      await Future<void>.delayed(Duration(milliseconds: 1));

      expect(globalEvents, [
        BoxEvent('key1', 'v1', false),
        BoxEvent('key2', 'v2', false),
        BoxEvent('key1', 'v1', true),
      ]);
      expect(keyEvents, [
        BoxEvent('key1', 'v1', false),
        BoxEvent('key1', 'v1', true),
      ]);

      await globalSub.cancel();
      notifier.notify(Frame('key1', 'v3'));
      notifier.notify(Frame('key2', 'v4'));
      await Future<void>.delayed(Duration(milliseconds: 1));

      expect(globalEvents, hasLength(3));
      expect(keyEvents, [
        BoxEvent('key1', 'v1', false),
        BoxEvent('key1', 'v1', true),
        BoxEvent('key1', 'v3', false),
      ]);

      await keySub.cancel();
      await notifier.close();
    });

    test('close() closes global and active per-key streams', () async {
      final notifier = ChangeNotifier();

      var globalDone = false;
      var key1Done = false;
      var key2Done = false;
      notifier.watch().listen((_) {}, onDone: () => globalDone = true);
      notifier.watch(key: 'key1').listen((_) {}, onDone: () => key1Done = true);
      notifier.watch(key: 'key2').listen((_) {}, onDone: () => key2Done = true);
      expect(notifier.keyControllerCount, 2);

      await notifier.close();
      expect(notifier.keyControllerCount, 0);
      expect(globalDone, isTrue);
      expect(key1Done, isTrue);
      expect(key2Done, isTrue);
    });

    test('close() with debug controller closes active per-key streams',
        () async {
      final controller = StreamControllerMock<BoxEvent>();
      returnFutureVoid(when(controller.close));
      final notifier = ChangeNotifier.debug(controller);

      var keyDone = false;
      notifier.watch(key: 'key1').listen((_) {}, onDone: () => keyDone = true);
      expect(notifier.keyControllerCount, 1);

      await notifier.close();
      verify(controller.close);
      expect(notifier.keyControllerCount, 0);
      expect(keyDone, isTrue);
    });
  });
}
