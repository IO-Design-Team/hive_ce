import 'dart:async';
import 'dart:isolate';

import 'package:hive_ce/hive.dart' hide IsolatedHive;
import 'package:hive_ce/src/backend/vm/storage_backend_vm.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/isolate/handler/isolate_entry_point.dart';
import 'package:hive_ce/src/isolate/isolated_hive.dart';
import 'package:isolate_channel/isolate_channel.dart';
import 'package:test/test.dart';

import '../util/print_utils.dart';
import 'common.dart';

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
      final hive = IsolatedHive();
      hive.entryPoint = (send) => silenceOutput(() => isolateEntryPoint(send));
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
        final hive = IsolatedHive();
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
          final hive = IsolatedHive();
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
          final hive = IsolatedHive();
          await hive.init(dir.path, isolateNameServer: ins);
          await expectLater(
            Future.wait([
              for (var i = 0; i < 100; i++)
                runIsolate(ins: ins, path: dir.path),
            ]),
            completes,
          );
          final box = hive.box<int>('test');
          expect(await box.length, 10000);
        });
      });

      group('warnings', () {
        test('unsafe isolate', () async {
          final patchedWarning =
              HiveImpl.unsafeIsolateWarning.replaceFirst(isolateNameRegex, '');

          final safeOutput =
              await captureOutput(() => Hive.init(null)).toList();
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
          final hive = IsolatedHive();
          addTearDown(hive.close);

          hive.entryPoint = (send) async {
            final connection = setupIsolate(send);
            final hiveChannel = IsolateMethodChannel('hive', connection);
            final testChannel = IsolateMethodChannel('test', connection);
            hiveChannel.setMethodCallHandler((_) {});
            testChannel.setMethodCallHandler(
              (_) => captureOutput(() => Hive.init(null)).toList(),
            );
          };
          await hive.init(null, isolateNameServer: StubIns());
          final channel = IsolateMethodChannel('test', hive.connection);
          final result = await channel.invokeListMethod('');
          expect(result, isEmpty);
        });

        test('no INS', () async {
          final unsafeOutput =
              await captureOutput(() => IsolatedHive().init(null)).toList();
          expect(
            unsafeOutput,
            contains(IsolatedHive.noIsolateNameServerWarning),
          );

          final safeOutput = await captureOutput(
            () => IsolatedHive().init(null, isolateNameServer: TestIns()),
          ).toList();
          expect(safeOutput, isEmpty);
        });

        test('lock file exists', () async {
          final dir = await getTempDir();
          final path = dir.path;
          Hive.init(path);
          await Hive.openBox('test');
          final output = await Isolate.run(() {
            Hive.init(path);
            return captureOutput(() => Hive.openBox('test')).toList();
          });

          expect(
            output,
            contains(StorageBackendVm.lockFileExistsWarning),
          );
        });

        test('lock file does not exist', () async {
          final dir = await getTempDir();
          final path = dir.path;
          final hive = IsolatedHive();
          await hive.init(path, isolateNameServer: StubIns());
          await hive.openBox('test');
          final output = await Isolate.run(() async {
            final hive = IsolatedHive();
            await hive.init(path, isolateNameServer: StubIns());
            return captureOutput(() => hive.openBox('test')).toList();
          });

          expect(output, isEmpty);
        });
      });
    },
    onPlatform: {
      'chrome': Skip('Isolates are not supported on web'),
    },
  );
}
