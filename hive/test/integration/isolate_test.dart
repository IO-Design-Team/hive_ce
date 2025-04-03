@TestOn('vm')
library;

import 'dart:async';
import 'dart:isolate';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/vm/storage_backend_vm.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:test/test.dart';

import '../util/print_utils.dart';
import '../tests/common.dart';
import 'integration.dart';

/// Exists to silence the warning about not passing an INS
class StubIns extends IsolateNameServer {
  @override
  SendPort? lookupPortByName(String name) => null;

  @override
  bool registerPortWithName(SendPort port, String name) => true;

  @override
  bool removePortNameMapping(String name) => true;
}

class TestIns extends IsolateNameServer {
  final _ports = <String, SendPort>{};

  @override
  SendPort? lookupPortByName(String name) => _ports[name];

  @override
  bool registerPortWithName(SendPort port, String name) {
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

void main() async {
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
              HiveImpl.unsafeIsolateWarning.replaceFirst(isolateNameRegex, '');

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
        });

        test('safe hive isolate', () async {
          final hive = IsolatedHiveImpl();
          addTearDown(hive.close);

          (hive as HiveIsolate).entryPoint = (send) async {
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
            contains(HiveIsolate.noIsolateNameServerWarning),
          );

          final safeOutput = await captureOutput(
            () => IsolatedHiveImpl().init(null, isolateNameServer: TestIns()),
          ).toList();
          expect(safeOutput, isEmpty);
        });

        test('unmatched isolation', () async {
          final dir = await getTempDir();
          final path = dir.path;

          await IsolatedHive.init(path, isolateNameServer: StubIns());
          Hive.init(path);

          await IsolatedHive.openBox('test');
          final output =
              await captureOutput(() => Hive.openBox('test')).toList();

          expect(
            output,
            contains(StorageBackendVm.unmatchedIsolationWarning),
          );
        });
      });

      test('IsolatedHive data compatable with Hive', () async {
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
    },
    onPlatform: {
      'chrome': Skip('Isolates are not supported on web'),
    },
  );
}
