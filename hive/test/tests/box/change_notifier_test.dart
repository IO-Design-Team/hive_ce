import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/change_notifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../common.dart';

class StreamControllerMock<T> extends Mock implements StreamController<T> {}

void main() {
  setUpAll(() {
    registerFallbackValue(const BoxEvent('key', null, false));
  });

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

      await notifier.close();
    });

    test('skips BoxEvent creation when no listeners are registered', () {
      final controller = StreamControllerMock<BoxEvent>();
      when(() => controller.hasListener).thenReturn(false);
      final notifier = ChangeNotifier.debug(controller);

      notifier.notify(Frame('key1', 'val1'));

      verify(() => controller.hasListener);
      verifyNever(() => controller.add(any()));
    });

    test('routes per-key events without global listeners', () async {
      final controller = StreamControllerMock<BoxEvent>();
      when(() => controller.hasListener).thenReturn(false);
      returnFutureVoid(when(controller.close));
      final notifier = ChangeNotifier.debug(controller);

      final events = <BoxEvent>[];
      final sub = notifier.watch(key: 'key1').listen(events.add);

      notifier.notify(Frame('key1', 'val1'));
      notifier.notify(Frame('key2', 'val2'));
      notifier.notify(Frame.deleted('key1'), deletedValue: 'val1');

      await Future.delayed(Duration(milliseconds: 1));

      expect(events.length, 2);
      expect(events[0].key, 'key1');
      expect(events[0].value, 'val1');
      expect(events[0].deleted, false);
      expect(events[1].key, 'key1');
      expect(events[1].value, 'val1');
      expect(events[1].deleted, true);
      verifyNever(() => controller.add(any()));

      await sub.cancel();
      expect(notifier.keyControllerCount, 0);
      await notifier.close();
    });

    test('cleans up per-key controller on last cancel and supports re-watch',
        () async {
      final notifier = ChangeNotifier();

      final key1EventsA = <BoxEvent>[];
      final key1EventsB = <BoxEvent>[];
      final key2Events = <BoxEvent>[];

      final sub1a = notifier.watch(key: 'key1').listen(key1EventsA.add);
      final sub1b = notifier.watch(key: 'key1').listen(key1EventsB.add);
      final sub2 = notifier.watch(key: 'key2').listen(key2Events.add);
      expect(notifier.keyControllerCount, 2);

      await sub1a.cancel();
      expect(notifier.keyControllerCount, 2);

      notifier.notify(Frame('key1', 'val1'));
      await Future.delayed(Duration(milliseconds: 1));
      expect(key1EventsA, isEmpty);
      expect(key1EventsB, [BoxEvent('key1', 'val1', false)]);

      await sub1b.cancel();
      expect(notifier.keyControllerCount, 1);

      await sub2.cancel();
      expect(notifier.keyControllerCount, 0);

      final reWatchEvents = <BoxEvent>[];
      final reSub = notifier.watch(key: 'key1').listen(reWatchEvents.add);
      expect(notifier.keyControllerCount, 1);

      notifier.notify(Frame('key1', 'val2'));
      await Future.delayed(Duration(milliseconds: 1));
      expect(reWatchEvents, [BoxEvent('key1', 'val2', false)]);

      await reSub.cancel();
      expect(notifier.keyControllerCount, 0);
      await notifier.close();
    });

    test('delivers shared event to simultaneous global and per-key listeners',
        () async {
      final notifier = ChangeNotifier();

      final globalEvents = <BoxEvent>[];
      final key1Events = <BoxEvent>[];
      final key2Events = <BoxEvent>[];

      final globalSub = notifier.watch().listen(globalEvents.add);
      final key1Sub = notifier.watch(key: 'key1').listen(key1Events.add);
      final key2Sub = notifier.watch(key: 'key2').listen(key2Events.add);

      notifier.notify(Frame('key1', 'val1'));
      notifier.notify(Frame('key2', 'val2'));
      notifier.notify(Frame.deleted('key1'), deletedValue: 'val1');

      await Future.delayed(Duration(milliseconds: 1));

      expect(globalEvents.length, 3);
      expect(key1Events.length, 2);
      expect(key2Events.length, 1);
      expect(identical(globalEvents[0], key1Events[0]), true);
      expect(identical(globalEvents[1], key2Events[0]), true);
      expect(identical(globalEvents[2], key1Events[1]), true);
      expect(key1Events[0].deleted, false);
      expect(key1Events[1].deleted, true);
      expect(key1Events[1].value, 'val1');

      await globalSub.cancel();
      await key1Sub.cancel();
      await key2Sub.cancel();
      await notifier.close();
    });

    test('close', () async {
      final controller = StreamControllerMock<BoxEvent>();
      returnFutureVoid(when(controller.close));
      final notifier = ChangeNotifier.debug(controller);

      await notifier.close();
      verify(controller.close);
    });

    test('close closes per-key controllers and clears map', () async {
      final notifier = ChangeNotifier();

      var key1Done = false;
      var key2Done = false;
      notifier.watch(key: 'key1').listen((_) {}, onDone: () => key1Done = true);
      notifier.watch(key: 'key2').listen((_) {}, onDone: () => key2Done = true);
      expect(notifier.keyControllerCount, 2);

      await notifier.close();

      expect(notifier.keyControllerCount, 0);
      expect(key1Done, true);
      expect(key2Done, true);
    });
  });
}
