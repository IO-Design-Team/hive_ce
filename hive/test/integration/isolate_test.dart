@TestOn('vm')
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate_name.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:hive_ce/src/util/logger.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:test/test.dart';

import '../util/print_utils.dart';
import '../tests/common.dart';
import 'integration.dart';

/// Exists to silence the warning about not passing an INS
class StubIns extends IsolateNameServer {
  @override
  dynamic lookupPortByName(String name) => null;

  @override
  bool registerPortWithName(dynamic port, String name) => true;

  @override
  bool removePortNameMapping(String name) => true;
}

class TestIns extends IsolateNameServer {
  final _ports = <String, SendPort>{};

  @override
  dynamic lookupPortByName(String name) => _ports[name];

  @override
  bool registerPortWithName(dynamic port, String name) {
    _ports[name] = port;
    return true;
  }

  @override
  bool removePortNameMapping(String name) {
    _ports.remove(name);
    return true;
  }
}

final isolateNameRegex = RegExp(r'\(current isolate: .+?\)');

void main() {
  Future<void> runIsolate({
    required IsolateNameServer ins,
    required String path,
    bool close = false,
  }) {
    return Isolate.run(() async {
      final hive = IsolatedHiveImpl();
      (hive as HiveIsolate).entryPoint =
          (send) => silenceOutput(() => isolateEntryPoint(send));
      await hive.init(path, isolateNameServer: ins);
      final box = await hive.openBox<int>('test');
      for (var i = 0; i < 100; i++) {
        await box.add(i);
      }
      if (close) await hive.close();
    });
  }

  group(
    'isolates',
    () {
      test('single without INS', () async {
        final dir = await getTempDir();
        final hive = IsolatedHiveImpl();
        await hive.init(dir.path, isolateNameServer: StubIns());
        await expectLater(
          runIsolate(ins: StubIns(), path: dir.path, close: true),
          completes,
        );
        final box = await hive.openBox<int>('test');
        expect(await box.length, 100);
      });

      group('multiple', () {
        test('without INS', () async {
          final dir = await getTempDir();
          final hive = IsolatedHiveImpl();
          (hive as HiveIsolate).entryPoint =
              (send) => silenceOutput(() => isolateEntryPoint(send));
          await hive.init(dir.path, isolateNameServer: StubIns());
          await expectLater(
            Future.wait([
              for (var i = 0; i < 100; i++)
                runIsolate(ins: StubIns(), path: dir.path),
            ]),
            completes,
          );
          final box = await hive.openBox<int>('test');
          expect(await box.length, isNot(10000));
        });

        test('with INS', () async {
          final dir = await getTempDir();
          final ins = TestIns();
          final hive = IsolatedHiveImpl();
          await hive.init(dir.path, isolateNameServer: ins);
          await expectLater(
            Future.wait([
              for (var i = 0; i < 100; i++)
                runIsolate(ins: ins, path: dir.path),
            ]),
            completes,
          );
          final box = await hive.openBox<int>('test');
          expect(await box.length, 10000);
        });
      });

      group('warnings', () {
        test('unsafe isolate', () async {
          final patchedWarning =
              HiveWarning.unsafeIsolate.replaceFirst(isolateNameRegex, '');

          final safeOutput = await Isolate.run(
            debugName: 'main',
            () => captureOutput(() => Hive.init(null)).toList(),
          );
          expect(safeOutput, isEmpty);

          final unsafeOutput = await Isolate.run(
            () => captureOutput(() => Hive.init(null)).toList(),
          );
          expect(
            unsafeOutput.first.replaceFirst(isolateNameRegex, ''),
            patchedWarning,
          );

          final ignoredOutput = await Isolate.run(
            () => captureOutput(() {
              HiveLogger.unsafeIsolateWarning = false;
              Hive.init(null);
            }).toList(),
          );
          expect(ignoredOutput, isEmpty);
        });

        test('safe hive isolate', () async {
          final hive = IsolatedHiveImpl();
          addTearDown(hive.close);

          (hive as HiveIsolate).entryPoint = (send) {
            final connection = setupIsolate(send);
            final hiveChannel = IsolateMethodChannel('hive', connection);
            final testChannel = IsolateMethodChannel('test', connection);
            hiveChannel.setMethodCallHandler((_) {});
            testChannel.setMethodCallHandler(
              (_) => captureOutput(() => Hive.init(null)).toList(),
            );
          };
          await hive.init(null, isolateNameServer: StubIns());
          final channel =
              IsolateMethodChannel('test', (hive as HiveIsolate).connection);
          final result = await channel.invokeListMethod('');
          expect(result, isEmpty);
        });

        test('no INS', () async {
          final unsafeOutput =
              await captureOutput(() => IsolatedHiveImpl().init(null)).toList();
          expect(
            unsafeOutput,
            contains(HiveWarning.noIsolateNameServer),
          );

          final safeOutput = await captureOutput(
            () => IsolatedHiveImpl().init(null, isolateNameServer: TestIns()),
          ).toList();
          expect(safeOutput, isEmpty);

          final ignoredOutput = await captureOutput(() {
            HiveLogger.noIsolateNameServerWarning = false;
            IsolatedHiveImpl().init(null);
          }).toList();
          expect(ignoredOutput, isEmpty);
        });

        test('unmatched isolation', () async {
          final dir = await getTempDir();
          final path = dir.path;

          await IsolatedHive.init(path, isolateNameServer: StubIns());
          Hive.init(path);

          await IsolatedHive.openBox('box1');
          final output =
              await captureOutput(() => Hive.openBox('box1')).toList();

          expect(
            output,
            contains(HiveWarning.unmatchedIsolation),
          );

          await IsolatedHive.openBox('box2');
          final ignoredOutput = await captureOutput(() async {
            HiveLogger.unmatchedIsolationWarning = false;
            await Hive.openBox('box2');
          }).toList();

          expect(
            ignoredOutput,
            isNot(contains(HiveWarning.unmatchedIsolation)),
          );
        });
      });

      test('IsolatedHive data compatible with Hive', () async {
        final dir = await getTempDir();

        final isolatedHive = IsolatedHiveImpl();
        addTearDown(isolatedHive.close);
        await isolatedHive.init(dir.path, isolateNameServer: StubIns());

        final isolatedBox = await isolatedHive.openBox('test');
        await isolatedBox.put('key', 'value');
        await isolatedBox.close();

        final hive = HiveImpl();
        addTearDown(hive.close);
        hive.init(dir.path);

        final box = await hive.openBox('test');
        expect(await box.get('key'), 'value');
      });

      test('Hive data compatible with IsolatedHive', () async {
        final dir = await getTempDir();

        final hive = HiveImpl();
        addTearDown(hive.close);
        hive.init(dir.path);

        final box = await hive.openBox('test');
        await box.put('key', 'value');
        await box.close();

        final isolatedHive = IsolatedHiveImpl();
        addTearDown(isolatedHive.close);
        await isolatedHive.init(dir.path, isolateNameServer: StubIns());

        final isolatedBox = await isolatedHive.openBox('test');
        expect(await isolatedBox.get('key'), 'value');
      });

      test('Encrypted IsolatedHive data compatible with Hive', () async {
        final dir = await getTempDir();
        final cipher = HiveAesCipher(Hive.generateSecureKey());

        final isolatedHive = IsolatedHiveImpl();
        addTearDown(isolatedHive.close);
        await isolatedHive.init(dir.path, isolateNameServer: StubIns());

        final isolatedBox =
            await isolatedHive.openBox('test', encryptionCipher: cipher);
        await isolatedBox.put('key', 'value');
        await isolatedBox.close();

        final hive = HiveImpl();
        addTearDown(hive.close);
        hive.init(dir.path);

        final box = await hive.openBox('test', encryptionCipher: cipher);
        expect(await box.get('key'), 'value');
      });

      test('Encrypted Hive data compatible with IsolatedHive', () async {
        final dir = await getTempDir();
        final cipher = HiveAesCipher(Hive.generateSecureKey());

        final hive = HiveImpl();
        addTearDown(hive.close);
        hive.init(dir.path);

        final box = await hive.openBox('test', encryptionCipher: cipher);
        await box.put('key', 'value');
        await box.close();

        final isolatedHive = IsolatedHiveImpl();
        addTearDown(isolatedHive.close);
        await isolatedHive.init(dir.path, isolateNameServer: StubIns());

        final isolatedBox =
            await isolatedHive.openBox('test', encryptionCipher: cipher);
        expect(await isolatedBox.get('key'), 'value');
      });

      test(
        'IsolatedHive data encrypted with no keyCrc is readable',
        () async {
          final dir = await getTempDir();
          final key = Hive.generateSecureKey();

          final isolatedHive = IsolatedHiveImpl();
          addTearDown(isolatedHive.close);
          await isolatedHive.init(dir.path, isolateNameServer: StubIns());

          final box = await isolatedHive.openBox(
            'test',
            encryptionCipher: ZeroKeyCrcCipher(key),
          );
          await box.put('key', 'value');
          await box.close();

          final box2 = await isolatedHive.openBox(
            'test',
            encryptionCipher: HiveAesCipher(key),
          );
          expect(await box2.get('key'), 'value');
        },
      );

      test('Encrypted IsolatedBox data compatible with IsolatedLazyBox',
          () async {
        final dir = await getTempDir();
        final key = Hive.generateSecureKey();

        final isolatedHive = IsolatedHiveImpl();
        addTearDown(isolatedHive.close);
        await isolatedHive.init(dir.path, isolateNameServer: StubIns());

        final box = await isolatedHive.openBox(
          'test',
          encryptionCipher: HiveAesCipher(key),
        );
        await box.put('key', 'value');
        await box.close();

        final lazyBox = await isolatedHive.openLazyBox(
          'test',
          encryptionCipher: HiveAesCipher(key),
        );
        expect(await lazyBox.get('key'), 'value');
      });

      test('Encrypted IsolatedLazyBox data compatible with IsolatedBox',
          () async {
        final dir = await getTempDir();
        final key = Hive.generateSecureKey();

        final isolatedHive = IsolatedHiveImpl();
        addTearDown(isolatedHive.close);
        await isolatedHive.init(dir.path, isolateNameServer: StubIns());

        final lazyBox = await isolatedHive.openLazyBox(
          'test',
          encryptionCipher: HiveAesCipher(key),
        );
        await lazyBox.put('key', 'value');
        await lazyBox.close();

        final box = await isolatedHive.openBox(
          'test',
          encryptionCipher: HiveAesCipher(key),
        );
        expect(await box.get('key'), 'value');
      });

      test('Stale send port', () async {
        final dir = await getTempDir();
        final hive = IsolatedHiveImpl();
        addTearDown(hive.close);

        final ins = TestIns();
        ins.registerPortWithName(ReceivePort().sendPort, hiveIsolateName);

        var spawned = false;
        (hive as HiveIsolate).spawnHiveIsolate = () {
          spawned = true;
          return spawnIsolate(isolateEntryPoint);
        };

        await hive.init(dir.path, isolateNameServer: ins);

        expect(spawned, isTrue);
      });

      group('write serialization and transfer', () {
        Uint8List makePayload(int length, int seed) =>
            Uint8List.fromList(List.generate(length, (i) => (i + seed) & 0xff));

        test('single writes around 65536-byte threshold persist across reopen',
            () async {
          final dir = await getTempDir();
          final hive1 = IsolatedHiveImpl();
          addTearDown(hive1.close);
          await hive1.init(dir.path, isolateNameServer: StubIns());

          // byteListT (1 byte) + uint32 length (4 bytes) + payload:
          // 65530 -> 65535 bytes (raw), 65531 -> 65536 (TTD), 65532 -> 65537 (TTD)
          final pBelow = makePayload(65530, 1);
          final pExact = makePayload(65531, 2);
          final pAbove = makePayload(65532, 3);
          final pLarge = makePayload(131072, 4);

          final box = await hive1.openBox<Uint8List>('single_eager');
          await box.put('below', pBelow);
          await box.put('exact', pExact);
          await box.put('above', pAbove);
          await box.put('z_replace', pBelow);
          final addedBelow = await box.add(pBelow);
          final addedExact = await box.add(pExact);
          final addedAbove = await box.add(pAbove);

          final replaceIndex = (await box.keys).toList().indexOf('z_replace');
          await box.putAt(replaceIndex, pLarge);

          expect(await box.get('below'), equals(pBelow));
          expect(await box.get('exact'), equals(pExact));
          expect(await box.get('above'), equals(pAbove));
          expect(await box.get(addedBelow), equals(pBelow));
          expect(await box.get(addedExact), equals(pExact));
          expect(await box.get(addedAbove), equals(pAbove));
          expect(await box.get('z_replace'), equals(pLarge));

          final lazyBox = await hive1.openLazyBox<Uint8List>('single_lazy');
          await lazyBox.put('below', pBelow);
          await lazyBox.put('exact', pExact);
          await lazyBox.put('z_replace', pBelow);
          final lazyIdx = await lazyBox.add(pAbove);
          final lazyReplaceIndex =
              (await lazyBox.keys).toList().indexOf('z_replace');
          await lazyBox.putAt(lazyReplaceIndex, pLarge);

          expect(await lazyBox.get('below'), equals(pBelow));
          expect(await lazyBox.get('exact'), equals(pExact));
          expect(await lazyBox.get(lazyIdx), equals(pAbove));
          expect(await lazyBox.get('z_replace'), equals(pLarge));

          await hive1.close();

          final hive2 = IsolatedHiveImpl();
          addTearDown(hive2.close);
          await hive2.init(dir.path, isolateNameServer: StubIns());

          final reopenedBox = await hive2.openBox<Uint8List>('single_eager');
          expect(await reopenedBox.get('below'), equals(pBelow));
          expect(await reopenedBox.get('exact'), equals(pExact));
          expect(await reopenedBox.get('above'), equals(pAbove));
          expect(await reopenedBox.get('z_replace'), equals(pLarge));

          final reopenedLazy =
              await hive2.openLazyBox<Uint8List>('single_lazy');
          expect(await reopenedLazy.get('below'), equals(pBelow));
          expect(await reopenedLazy.get('exact'), equals(pExact));
          expect(await reopenedLazy.get(lazyIdx), equals(pAbove));
          expect(await reopenedLazy.get('z_replace'), equals(pLarge));
        });

        test('putAll and addAll handle empty, small, mixed-large, and lazy',
            () async {
          final dir = await getTempDir();
          final hive1 = IsolatedHiveImpl();
          addTearDown(hive1.close);
          await hive1.init(dir.path, isolateNameServer: StubIns());

          final box = await hive1.openBox<dynamic>('batch_eager');
          await box.putAll({});
          expect(await box.addAll([]), isEmpty);
          expect(await box.length, 0);

          await box.putAll({'s1': 'hello', 'n1': 42});
          final smallAdded = await box.addAll(['a', 99]);
          expect(smallAdded, [0, 1]);

          final largeA = makePayload(40000, 10);
          final largeB = makePayload(50000, 20);
          await box.putAll({
            'k_small': 'tiny',
            'k_large_a': largeA,
            'k_num': 3.14,
            'k_large_b': largeB,
          });

          var evalCount = 0;
          final lazyIterable = Iterable<dynamic>.generate(4, (i) {
            evalCount++;
            return i == 2 ? makePayload(70000, 30) : 'lazy_$i';
          });
          final lazyKeys = await box.addAll(lazyIterable);
          expect(evalCount, 4);
          expect(lazyKeys, [2, 3, 4, 5]);

          expect(await box.get('s1'), 'hello');
          expect(await box.get('n1'), 42);
          expect(await box.get('k_small'), 'tiny');
          expect(await box.get('k_large_a'), equals(largeA));
          expect(await box.get('k_num'), 3.14);
          expect(await box.get('k_large_b'), equals(largeB));
          expect(await box.get(4), equals(makePayload(70000, 30)));
          expect(await box.get(5), 'lazy_3');

          final mapBeforeClose = await box.toMap();
          expect(mapBeforeClose['k_large_a'], equals(largeA));
          expect(mapBeforeClose[4], equals(makePayload(70000, 30)));
          expect((await box.values).length, 12);

          final lazyBox = await hive1.openLazyBox<dynamic>('batch_lazy');
          await lazyBox.putAll({});
          expect(await lazyBox.addAll([]), isEmpty);
          await lazyBox.putAll({
            'p1': 'v1',
            'p2': largeA,
            'p3': largeB,
          });
          final lazyBoxKeys = await lazyBox.addAll(['item0', largeB]);
          expect(lazyBoxKeys, [0, 1]);

          await hive1.close();

          final hive2 = IsolatedHiveImpl();
          addTearDown(hive2.close);
          await hive2.init(dir.path, isolateNameServer: StubIns());

          final reopenedBox = await hive2.openBox<dynamic>('batch_eager');
          expect(await reopenedBox.toMap(), equals(mapBeforeClose));

          final reopenedLazy = await hive2.openLazyBox<dynamic>('batch_lazy');
          expect(await reopenedLazy.get('p1'), 'v1');
          expect(await reopenedLazy.get('p2'), equals(largeA));
          expect(await reopenedLazy.get('p3'), equals(largeB));
          expect(await reopenedLazy.get(0), 'item0');
          expect(await reopenedLazy.get(1), equals(largeB));
        });

        test('encrypted boxes round-trip single and packed batch writes',
            () async {
          final dir = await getTempDir();
          final cipher = HiveAesCipher(Hive.generateSecureKey());

          final hive1 = IsolatedHiveImpl();
          addTearDown(hive1.close);
          await hive1.init(dir.path, isolateNameServer: StubIns());

          final smallBytes = makePayload(100, 5);
          final largeBytes = makePayload(70000, 6);
          final midBytes = makePayload(40000, 7);

          final box = await hive1.openBox<dynamic>(
            'enc_eager',
            encryptionCipher: cipher,
          );
          await box.put('small', smallBytes);
          await box.put('large', largeBytes);
          await box.put('z_replace', smallBytes);
          final addedKey = await box.add(largeBytes);
          final replaceIndex = (await box.keys).toList().indexOf('z_replace');
          await box.putAt(replaceIndex, midBytes);

          await box.putAll({
            'b_small': 'secret',
            'b_mid': midBytes,
            'b_large': largeBytes,
          });
          final batchKeys = await box.addAll(['s', largeBytes]);

          final lazyBox = await hive1.openLazyBox<dynamic>(
            'enc_lazy',
            encryptionCipher: cipher,
          );
          await lazyBox.put('small', smallBytes);
          await lazyBox.put('large', largeBytes);
          await lazyBox.putAll({
            'lb_small': 'lazy_secret',
            'lb_large': largeBytes,
          });
          final lazyAdded = await lazyBox.addAll(['x', midBytes, largeBytes]);

          expect(await box.get('large'), equals(largeBytes));
          expect(await box.get(addedKey), equals(largeBytes));
          expect(await box.get('z_replace'), equals(midBytes));
          expect(await box.get('b_small'), 'secret');
          expect(await box.get('b_large'), equals(largeBytes));
          expect(await box.get(batchKeys[1]), equals(largeBytes));
          expect(await lazyBox.get('lb_large'), equals(largeBytes));

          await hive1.close();

          final hive2 = IsolatedHiveImpl();
          addTearDown(hive2.close);
          await hive2.init(dir.path, isolateNameServer: StubIns());

          final reopenedBox = await hive2.openBox<dynamic>(
            'enc_eager',
            encryptionCipher: cipher,
          );
          expect(await reopenedBox.get('large'), equals(largeBytes));
          expect(await reopenedBox.get(addedKey), equals(largeBytes));
          expect(await reopenedBox.get('z_replace'), equals(midBytes));
          expect(await reopenedBox.get('b_small'), 'secret');
          expect(await reopenedBox.get('b_mid'), equals(midBytes));
          expect(await reopenedBox.get('b_large'), equals(largeBytes));
          expect(await reopenedBox.get(batchKeys[0]), 's');
          expect(await reopenedBox.get(batchKeys[1]), equals(largeBytes));

          final reopenedLazy = await hive2.openLazyBox<dynamic>(
            'enc_lazy',
            encryptionCipher: cipher,
          );
          expect(await reopenedLazy.get('small'), equals(smallBytes));
          expect(await reopenedLazy.get('large'), equals(largeBytes));
          expect(await reopenedLazy.get('lb_small'), 'lazy_secret');
          expect(await reopenedLazy.get('lb_large'), equals(largeBytes));
          expect(await reopenedLazy.get(lazyAdded[0]), 'x');
          expect(await reopenedLazy.get(lazyAdded[1]), equals(midBytes));
          expect(await reopenedLazy.get(lazyAdded[2]), equals(largeBytes));
        });

        test('writer resets cleanly after serialization failure', () async {
          final dir = await getTempDir();
          final hive = IsolatedHiveImpl();
          addTearDown(hive.close);
          await hive.init(dir.path, isolateNameServer: StubIns());

          final box = await hive.openBox<dynamic>('error_recovery');
          await box.put('seed', 'initial');

          await expectLater(
            () => box.put('bad', _UnregisteredType()),
            throwsHiveError(['unknown type']),
          );
          await expectLater(
            () => box.putAt(0, _UnregisteredType()),
            throwsHiveError(['unknown type']),
          );
          await expectLater(
            () => box.add(_UnregisteredType()),
            throwsHiveError(['unknown type']),
          );
          await expectLater(
            () => box.putAll({
              'partial': makePayload(70000, 8),
              'bad': _UnregisteredType(),
            }),
            throwsHiveError(['unknown type']),
          );
          await expectLater(
            () => box.addAll(['partial', _UnregisteredType()]),
            throwsHiveError(['unknown type']),
          );

          expect(await box.containsKey('partial'), isFalse);
          expect(await box.get('seed'), 'initial');

          final large = makePayload(70000, 9);
          await box.put('good', 'clean');
          await box.putAll({'g1': 123, 'g2': large});
          final keys = await box.addAll(['after1', large]);

          expect(await box.get('good'), 'clean');
          expect(await box.get('g1'), 123);
          expect(await box.get('g2'), equals(large));
          expect(await box.get(keys[0]), 'after1');
          expect(await box.get(keys[1]), equals(large));
        });
      });
    },
    onPlatform: {
      'chrome': Skip('Isolates are not supported on web'),
    },
  );
}

/// Test cipher that always returns a zero key CRC
class ZeroKeyCrcCipher extends HiveAesCipher {
  ZeroKeyCrcCipher(super.key);

  @override
  int calculateKeyCrc() => 0;
}

class _UnregisteredType {}
