@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/backend/vm/read_write_sync.dart';
import 'package:hive_ce/src/backend/vm/storage_backend_vm.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/io/frame_io_helper.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../../common.dart';
import '../../frames.dart';
import '../../mocks.dart';

const testMap = {
  'SomeKey': 123,
  'AnotherKey': ['Just', 456, 'a', 333, 'List'],
  'Random Double list': [1.0, 2.0, 10.0, double.infinity],
  'Unicode:': '👋',
  'Null': null,
  'LastKey': true,
};

Uint8List getFrameBytes(Iterable<Frame> frames) {
  final writer = BinaryWriterImpl(testRegistry);
  for (final frame in frames) {
    writer.writeFrame(frame);
  }
  return writer.toBytes();
}

Uint8List _encodeFrames(List<Frame> frames) {
  final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl);
  var offset = 0;
  for (final frame in frames) {
    final length = writer.writeFrame(frame);
    frame
      ..offset = offset
      ..length = length;
    offset += length;
  }
  return writer.toBytes();
}

class _CountingRandomAccessFile extends Fake implements RandomAccessFile {
  final RandomAccessFile _inner;

  var setPositionCalls = 0;
  var setPositionSyncCalls = 0;
  var readCalls = 0;
  var readSyncCalls = 0;
  var readIntoCalls = 0;
  var readIntoSyncCalls = 0;

  _CountingRandomAccessFile(this._inner);

  @override
  Future<RandomAccessFile> setPosition(int position) async {
    setPositionCalls++;
    await _inner.setPosition(position);
    return this;
  }

  @override
  void setPositionSync(int position) {
    setPositionSyncCalls++;
    _inner.setPositionSync(position);
  }

  @override
  Future<Uint8List> read(int count) {
    readCalls++;
    return _inner.read(count);
  }

  @override
  Uint8List readSync(int count) {
    readSyncCalls++;
    return _inner.readSync(count);
  }

  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) {
    readIntoCalls++;
    return _inner.readInto(buffer, start, end);
  }

  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) {
    readIntoSyncCalls++;
    return _inner.readIntoSync(buffer, start, end);
  }

  @override
  Future<void> close() => _inner.close();
}

StorageBackendVm _getBackend({
  File? file,
  File? lockFile,
  bool crashRecovery = false,
  HiveCipher? cipher,
  int? keyCrc,
  FrameIoHelper? ioHelper,
  ReadWriteSync? sync,
  RandomAccessFile? readRaf,
  RandomAccessFile? writeRaf,
}) {
  final backend = StorageBackendVm.debug(
    file ?? MockFile(),
    lockFile ?? MockFile(),
    crashRecovery,
    cipher,
    keyCrc,
    ioHelper ?? MockFrameIoHelper(),
    sync ?? ReadWriteSync(),
  );
  if (readRaf != null) {
    backend.readRaf = readRaf;
  }
  if (writeRaf != null) {
    backend.writeRaf = writeRaf;
  }
  return backend;
}

void main() {
  setUpAll(() {
    registerFallbackValue(KeystoreFake());
    registerFallbackValue(TypeRegistryFake());
  });

  group('StorageBackendVm', () {
    test('.path returns path for of open box file', () {
      // This is a test
      // ignore: rexios_lints/do_not_use_raw_paths
      final file = File('some/path');
      final backend = _getBackend(file: file);
      expect(backend.path, 'some/path');
    });

    test('.supportsCompaction is true', () {
      final backend = _getBackend();
      expect(backend.supportsCompaction, true);
    });

    group('.open()', () {
      test('readFile & writeFile', () async {
        final file = MockFile();
        final readRaf = MockRandomAccessFile();
        final writeRaf = MockRandomAccessFile();
        when(file.open).thenAnswer((i) => Future.value(readRaf));
        when(() => file.open(mode: FileMode.writeOnlyAppend))
            .thenAnswer((i) => Future.value(writeRaf));
        when(writeRaf.length).thenAnswer((_) => Future.value(0));

        final backend = _getBackend(file: file);
        await backend.open();
        expect(backend.readRaf, readRaf);
        expect(backend.writeRaf, writeRaf);
      });

      test('writeOffset', () async {
        final file = MockFile();
        final writeFile = MockRandomAccessFile();
        final readRaf = MockRandomAccessFile();
        when(() => file.open(mode: FileMode.writeOnlyAppend))
            .thenAnswer((i) => Future.value(writeFile));
        when(file.open).thenAnswer((i) => Future.value(readRaf));
        when(writeFile.length).thenAnswer((i) => Future.value(123));

        final backend = _getBackend(file: file);
        await backend.open();
        expect(backend.writeOffset, 123);
      });
    });

    group('.initialize()', () {
      File getLockFile() {
        final lockMockFile = MockFile();
        when(() => lockMockFile.open(mode: FileMode.write))
            .thenAnswer((i) => Future.value(MockRandomAccessFile()));
        return lockMockFile;
      }

      FrameIoHelper getFrameIoHelper(int recoveryOffset) {
        final helper = MockFrameIoHelper();
        when(() => helper.framesFromFile(any(), any(), any(), any(), any()))
            .thenAnswer((i) => Future.value(recoveryOffset));
        when(() => helper.keysFromFile(any(), any(), any(), any()))
            .thenAnswer((i) => Future.value(recoveryOffset));
        return helper;
      }

      void runTests(bool lazy) {
        test('opens lock file and acquires lock', () async {
          final lockFile = MockFile();
          final lockRaf = MockRandomAccessFile();
          when(() => lockFile.open(mode: FileMode.write))
              .thenAnswer((i) => Future.value(lockRaf));
          when(lockRaf.lock).thenAnswer((i) => Future.value(lockRaf));

          final backend = _getBackend(
            lockFile: lockFile,
            ioHelper: getFrameIoHelper(-1),
          );
          when(() => backend.path).thenReturn('nullPath');

          await backend.initialize(
            TypeRegistryImpl.nullImpl,
            MockKeystore(),
            lazy,
          );
          verify(lockRaf.lock);
        });

        test('recoveryOffset with crash recovery', () async {
          final writeRaf = MockRandomAccessFile();
          final lockFile = getLockFile();
          final lockRaf = MockRandomAccessFile();

          final backend = _getBackend(
            lockFile: lockFile,
            ioHelper: getFrameIoHelper(20),
            crashRecovery: true,
            writeRaf: writeRaf,
          );
          when(() => backend.path).thenReturn('nullPath');
          when(() => lockFile.open(mode: FileMode.write))
              .thenAnswer((i) => Future.value(lockRaf));
          when(lockRaf.lock).thenAnswer((i) => Future.value(lockRaf));
          when(() => writeRaf.truncate(20))
              .thenAnswer((i) => Future.value(writeRaf));
          when(() => writeRaf.setPosition(20))
              .thenAnswer((i) => Future.value(writeRaf));

          await backend.initialize(
            TypeRegistryImpl.nullImpl,
            MockKeystore(),
            lazy,
          );
          verify(() => writeRaf.truncate(20));
          verify(() => writeRaf.setPosition(20));
        });

        test('recoveryOffset without crash recovery', () async {
          final lockFile = getLockFile();
          final lockRaf = MockRandomAccessFile();

          final backend = _getBackend(
            lockFile: lockFile,
            ioHelper: getFrameIoHelper(20),
            crashRecovery: false,
          );
          when(() => backend.path).thenReturn('nullPath');
          when(() => lockFile.open(mode: FileMode.write))
              .thenAnswer((i) => Future.value(lockRaf));
          when(lockRaf.lock).thenAnswer((i) => Future.value(lockRaf));

          await expectLater(
            () => backend.initialize(
              TypeRegistryImpl.nullImpl,
              MockKeystore(),
              lazy,
            ),
            throwsHiveError(['corrupted']),
          );
        });
      }

      group('(not lazy)', () {
        runTests(false);
      });

      group('(lazy)', () {
        runTests(true);
      });
    });

    group('.readValue()', () {
      test('reads value with offset', () async {
        final frameBytes = getFrameBytes([Frame('test', 123)]);
        final readRaf = await getTempRaf([1, 2, 3, 4, 5, ...frameBytes]);

        final backend = _getBackend(readRaf: readRaf)
          // The registry needs to be initialized before reading values, and
          // because we do not call StorageBackendVM.initialize(), we set it
          // manually.
          ..registry = TypeRegistryImpl.nullImpl;
        final value = await backend.readValue(
          Frame('test', 123, length: frameBytes.length, offset: 5),
        );
        expect(value, 123);

        await readRaf.close();
      });

      test('throws exception when frame cannot be read', () async {
        final readRaf = await getTempRaf([1, 2, 3, 4, 5]);
        final backend = _getBackend(readRaf: readRaf)
          // The registry needs to be initialized before reading values, and
          // because we do not call StorageBackendVM.initialize(), we set it
          // manually.
          ..registry = TypeRegistryImpl.nullImpl;

        final frame = Frame('test', 123, length: frameBytes.length, offset: 0);
        await expectLater(
          () => backend.readValue(frame),
          throwsHiveError(['corrupted']),
        );

        await readRaf.close();
      });

      test('activates 16 KB read-ahead after 2 sequential reads', () async {
        final frames = [for (var i = 0; i < 10; i++) Frame('k$i', 'val_$i')];
        final bytes = _encodeFrames(frames);
        final countingRaf = _CountingRandomAccessFile(await getTempRaf(bytes));

        final backend = _getBackend(readRaf: countingRaf)
          ..registry = TypeRegistryImpl.nullImpl;

        expect(await backend.readValue(frames[0]), 'val_0');
        expect(countingRaf.readCalls, 1);
        expect(countingRaf.readIntoCalls, 0);
        expect(countingRaf.setPositionCalls, 1);

        expect(await backend.readValue(frames[1]), 'val_1');
        expect(countingRaf.readCalls, 2);
        expect(countingRaf.readIntoCalls, 0);
        expect(countingRaf.setPositionCalls, 2);

        expect(await backend.readValue(frames[2]), 'val_2');
        expect(countingRaf.readCalls, 2);
        expect(countingRaf.readIntoCalls, 1);
        expect(countingRaf.setPositionCalls, 3);

        for (var i = 3; i < frames.length; i++) {
          expect(await backend.readValue(frames[i]), 'val_$i');
        }
        expect(countingRaf.readCalls, 2);
        expect(countingRaf.readIntoCalls, 1);
        expect(countingRaf.setPositionCalls, 3);

        await countingRaf.close();
      });

      test(
        'refills read-ahead buffer cleanly across multiple 16 KB windows',
        () async {
          final frames = [
            for (var i = 0; i < 550; i++)
              Frame('k$i', 'value_${i}_${'a' * 40}'),
          ];
          final bytes = _encodeFrames(frames);
          expect(bytes.length, greaterThan(16384 * 2));
          final countingRaf = _CountingRandomAccessFile(
            await getTempRaf(bytes),
          );

          final backend = _getBackend(readRaf: countingRaf)
            ..registry = TypeRegistryImpl.nullImpl;

          for (var i = 0; i < frames.length; i++) {
            expect(
              await backend.readValue(frames[i]),
              'value_${i}_${'a' * 40}',
            );
          }

          expect(countingRaf.readCalls, 2);
          expect(countingRaf.readIntoCalls, inInclusiveRange(2, 4));
          expect(countingRaf.setPositionCalls, 2 + countingRaf.readIntoCalls);

          await countingRaf.close();
        },
      );

      test(
          'uses sync IO in isolated mode and detaches verbatim bytes across refills',
          () async {
        final frames = [
          for (var i = 0; i < 400; i++) Frame('k$i', 'iso_${i}_${'b' * 50}'),
        ];
        final bytes = _encodeFrames(frames);
        expect(bytes.length, greaterThan(16384));
        final countingRaf = _CountingRandomAccessFile(await getTempRaf(bytes));

        final file = MockFile();
        when(() => file.path).thenReturn('nullPath');
        final lockFile = MockFile();
        final lockRaf = MockRandomAccessFile();
        when(() => lockFile.open(mode: FileMode.write))
            .thenAnswer((_) => Future.value(lockRaf));
        when(lockRaf.lock).thenAnswer((_) => Future.value(lockRaf));
        final ioHelper = MockFrameIoHelper();
        when(() => ioHelper.keysFromFile(any(), any(), any(), any()))
            .thenAnswer((_) => Future.value(-1));

        final backend = _getBackend(
          file: file,
          lockFile: lockFile,
          ioHelper: ioHelper,
          readRaf: countingRaf,
        );
        await backend.initialize(
          TypeRegistryImpl.nullImpl,
          MockKeystore(),
          true,
          isolated: true,
        );

        await backend.readValue(frames[0], verbatim: true);
        await backend.readValue(frames[1], verbatim: true);
        final frame2Bytes =
            await backend.readValue(frames[2], verbatim: true) as Uint8List;
        final frame2Snapshot = Uint8List.fromList(frame2Bytes);

        for (var i = 3; i < frames.length; i++) {
          final raw =
              await backend.readValue(frames[i], verbatim: true) as Uint8List;
          expect(raw, isNotEmpty);
        }

        expect(frame2Bytes, frame2Snapshot);
        expect(countingRaf.readSyncCalls, 2);
        expect(countingRaf.readCalls, 0);
        expect(countingRaf.readIntoSyncCalls, greaterThanOrEqualTo(2));
        expect(countingRaf.readIntoCalls, 0);
        expect(
          countingRaf.setPositionSyncCalls,
          2 + countingRaf.readIntoSyncCalls,
        );

        await countingRaf.close();
      });

      test(
          'does not activate read-ahead for random reads and resets streak on out-of-window jump',
          () async {
        final frames = [
          for (var i = 0; i < 500; i++) Frame('k$i', 'rand_${i}_${'c' * 45}'),
        ];
        final bytes = _encodeFrames(frames);
        final countingRaf = _CountingRandomAccessFile(await getTempRaf(bytes));

        final backend = _getBackend(readRaf: countingRaf)
          ..registry = TypeRegistryImpl.nullImpl;

        const randomOrder = [0, 5, 2, 8, 1, 9, 3, 7, 4, 6];
        for (final idx in randomOrder) {
          expect(
            await backend.readValue(frames[idx]),
            'rand_${idx}_${'c' * 45}',
          );
        }
        expect(countingRaf.readIntoCalls, 0);
        expect(countingRaf.readCalls, randomOrder.length);

        // Activate read-ahead with 3 sequential reads, then jump out of window.
        final baseReadCalls = countingRaf.readCalls;
        expect(await backend.readValue(frames[0]), 'rand_0_${'c' * 45}');
        expect(await backend.readValue(frames[1]), 'rand_1_${'c' * 45}');
        expect(await backend.readValue(frames[2]), 'rand_2_${'c' * 45}');
        expect(countingRaf.readCalls, baseReadCalls + 2);
        expect(countingRaf.readIntoCalls, 1);

        // Jumping past the 16 KB window must reset streak and avoid readInto.
        expect(await backend.readValue(frames[499]), 'rand_499_${'c' * 45}');
        expect(await backend.readValue(frames[350]), 'rand_350_${'c' * 45}');
        expect(countingRaf.readIntoCalls, 1);
        expect(countingRaf.readCalls, baseReadCalls + 4);

        await countingRaf.close();
      });

      test('bypasses read-ahead for frames larger than 16 KB', () async {
        final largePayload = 'L' * 20000;
        final frames = [
          Frame('k0', 'small_0'),
          Frame('k1', 'small_1'),
          Frame('k2', largePayload),
          Frame('k3', 'small_3'),
          Frame('k4', 'small_4'),
          Frame('k5', 'small_5'),
        ];
        final bytes = _encodeFrames(frames);
        final countingRaf = _CountingRandomAccessFile(await getTempRaf(bytes));

        final backend = _getBackend(readRaf: countingRaf)
          ..registry = TypeRegistryImpl.nullImpl;

        expect(await backend.readValue(frames[0]), 'small_0');
        expect(await backend.readValue(frames[1]), 'small_1');
        expect(await backend.readValue(frames[2]), largePayload);
        expect(countingRaf.readCalls, 3);
        expect(countingRaf.readIntoCalls, 0);

        expect(await backend.readValue(frames[3]), 'small_3');
        expect(countingRaf.readCalls, 3);
        expect(countingRaf.readIntoCalls, 1);

        expect(await backend.readValue(frames[4]), 'small_4');
        expect(await backend.readValue(frames[5]), 'small_5');
        expect(countingRaf.readCalls, 3);
        expect(countingRaf.readIntoCalls, 1);

        await countingRaf.close();
      });

      test(
        'throws HiveError when frame is truncated during read-ahead refill',
        () async {
          final frames = [
            Frame('k0', 'v0'),
            Frame('k1', 'v1'),
            Frame('k2', 'v2_longer_payload'),
          ];
          final fullBytes = _encodeFrames(frames);
          final truncatedBytes = fullBytes.sublist(0, fullBytes.length - 3);
          final countingRaf = _CountingRandomAccessFile(
            await getTempRaf(truncatedBytes),
          );

          final backend = _getBackend(readRaf: countingRaf)
            ..registry = TypeRegistryImpl.nullImpl;

          expect(await backend.readValue(frames[0]), 'v0');
          expect(await backend.readValue(frames[1]), 'v1');
          await expectLater(
            () => backend.readValue(frames[2]),
            throwsHiveError(['corrupted']),
          );
          expect(await backend.readValue(frames[0]), 'v0');

          await countingRaf.close();
        },
      );

      test('clear() invalidates read-ahead cache', () async {
        final dir = await getTempDir();
        final file = File(path.join(dir.path, 'clear_test.hive'));
        final lockFile = File(path.join(dir.path, 'clear_test.lock'));
        await file.create(recursive: true);

        final backend = StorageBackendVm(file, lockFile, false, null, null);
        var closed = false;
        addTearDown(() async {
          if (!closed) {
            await backend.close();
          }
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        });

        await backend.open();
        await backend.initialize(
          TypeRegistryImpl.nullImpl,
          Keystore.debug(),
          true,
        );
        final countingRaf = _CountingRandomAccessFile(backend.readRaf);
        backend.readRaf = countingRaf;

        final oldFrames = [for (var i = 0; i < 5; i++) Frame('k$i', 'old_$i')];
        await backend.writeFrames(oldFrames);
        expect(await backend.readValue(oldFrames[0]), 'old_0');
        expect(await backend.readValue(oldFrames[1]), 'old_1');
        expect(await backend.readValue(oldFrames[2]), 'old_2');
        expect(countingRaf.readCalls, 2);
        expect(countingRaf.readIntoCalls, 1);

        await backend.clear();

        final newFrames = [for (var i = 0; i < 5; i++) Frame('k$i', 'new_$i')];
        await backend.writeFrames(newFrames);
        expect(await backend.readValue(newFrames[0]), 'new_0');
        expect(await backend.readValue(newFrames[1]), 'new_1');
        expect(countingRaf.readCalls, 4);
        expect(countingRaf.readIntoCalls, 1);

        expect(await backend.readValue(newFrames[2]), 'new_2');
        expect(await backend.readValue(newFrames[3]), 'new_3');
        expect(await backend.readValue(newFrames[4]), 'new_4');
        expect(countingRaf.readCalls, 4);
        expect(countingRaf.readIntoCalls, 2);

        await backend.close();
        closed = true;
      });

      test('compact() invalidates read-ahead cache', () async {
        final dir = await getTempDir();
        final file = File(path.join(dir.path, 'compact_test.hive'));
        final lockFile = File(path.join(dir.path, 'compact_test.lock'));
        await file.create(recursive: true);

        final backend = StorageBackendVm(file, lockFile, false, null, null);
        var closed = false;
        addTearDown(() async {
          if (!closed) {
            await backend.close();
          }
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        });

        await backend.open();
        await backend.initialize(
          TypeRegistryImpl.nullImpl,
          Keystore.debug(),
          true,
        );

        final f0 = Frame('k0', 'keep_0');
        final f1 = Frame('k1', 'drop_medium_key');
        final f2 = Frame(
          'k2',
          'keep_2_with_longer_payload_so_f3_shifts_inside_old_window',
        );
        final f3 = Frame('k3', 'keep_3');
        final f4 = Frame('k4', 'keep_4');
        await backend.writeFrames([f0, f1, f2, f3, f4]);

        // Warm read-ahead starting at f2.offset so old window spans f2..f4.
        expect(await backend.readValue(f0), 'keep_0');
        expect(await backend.readValue(f1), 'drop_medium_key');
        expect(
          await backend.readValue(f2),
          'keep_2_with_longer_payload_so_f3_shifts_inside_old_window',
        );

        await backend.compact([f0, f2, f3, f4]);

        expect(await backend.readValue(f0), 'keep_0');
        expect(
          await backend.readValue(f2),
          'keep_2_with_longer_payload_so_f3_shifts_inside_old_window',
        );
        expect(await backend.readValue(f3), 'keep_3');
        expect(await backend.readValue(f4), 'keep_4');

        await backend.close();
        closed = true;
      });

      test('close() invalidates read-ahead cache', () async {
        final frames1 = [for (var i = 0; i < 4; i++) Frame('k$i', 'first_$i')];
        final frames2 = [for (var i = 0; i < 4; i++) Frame('k$i', 'second_$i')];

        final readRaf1 = _CountingRandomAccessFile(
          await getTempRaf(_encodeFrames(frames1)),
        );
        final writeRaf = MockRandomAccessFile();
        final lockRaf = MockRandomAccessFile();
        final lockFile = MockFile();
        returnFutureVoid(when(writeRaf.close));
        returnFutureVoid(when(lockRaf.close));
        when(lockFile.delete).thenAnswer((_) => Future.value(lockFile));

        final backend = _getBackend(
          lockFile: lockFile,
          readRaf: readRaf1,
          writeRaf: writeRaf,
        )
          ..registry = TypeRegistryImpl.nullImpl
          ..lockRaf = lockRaf;

        expect(await backend.readValue(frames1[0]), 'first_0');
        expect(await backend.readValue(frames1[1]), 'first_1');
        expect(await backend.readValue(frames1[2]), 'first_2');
        expect(readRaf1.readIntoCalls, 1);

        await backend.close();

        final readRaf2 = _CountingRandomAccessFile(
          await getTempRaf(_encodeFrames(frames2)),
        );
        backend.readRaf = readRaf2;

        expect(await backend.readValue(frames2[3]), 'second_3');
        expect(readRaf2.readCalls, 1);
        expect(readRaf2.readIntoCalls, 0);

        await readRaf2.close();
      });
    });

    group('.writeFrames()', () {
      test('writes bytes', () async {
        final frames = [Frame('key1', 'value'), Frame('key2', null)];
        final bytes = getFrameBytes(frames);

        final writeRaf = MockRandomAccessFile();
        when(() => writeRaf.setPosition(0))
            .thenAnswer((i) => Future.value(writeRaf));
        when(() => writeRaf.writeFrom(bytes))
            .thenAnswer((i) => Future.value(writeRaf));

        final backend = _getBackend(writeRaf: writeRaf)
          // The registry needs to be initialized before writing values, and
          // because we do not call StorageBackendVM.initialize(), we set it
          // manually.
          ..registry = TypeRegistryImpl.nullImpl;

        await backend.writeFrames(frames);
        verify(() => writeRaf.writeFrom(bytes));
      });

      test('updates offsets', () async {
        final frames = [Frame('key1', 'value'), Frame('key2', null)];

        final writeRaf = MockRandomAccessFile();
        when(() => writeRaf.setPosition(5))
            .thenAnswer((i) => Future.value(writeRaf));
        when(() => writeRaf.writeFrom(any()))
            .thenAnswer((i) => Future.value(writeRaf));

        final backend = _getBackend(writeRaf: writeRaf)
          // The registry needs to be initialized before writing values, and
          // because we do not call StorageBackendVM.initialize(), we set it
          // manually.
          ..registry = TypeRegistryImpl.nullImpl;
        backend.writeOffset = 5;

        await backend.writeFrames(frames);
        expect(frames, [
          Frame('key1', 'value', length: 24, offset: 5),
          Frame('key2', null, length: 15, offset: 29),
        ]);
        expect(backend.writeOffset, 44);
      });

      test('resets writeOffset on error', () async {
        final writeRaf = MockRandomAccessFile();
        when(() => writeRaf.writeFrom(any())).thenThrow('error');
        final backend = _getBackend(writeRaf: writeRaf)
          // The registry needs to be initialized before writing values, and
          // because we do not call StorageBackendVM.initialize(), we set it
          // manually.
          ..registry = TypeRegistryImpl.nullImpl;
        backend.writeOffset = 123;

        await expectLater(
          () => backend.writeFrames([Frame('key1', 'value')]),
          throwsA(anything),
        );
        verify(() => writeRaf.setPosition(123));
        expect(backend.writeOffset, 123);
      });
    });

    /*group('.compact()', () {
      //TODO improve this test
      test('check compaction', () async {
        var bytes = BytesBuilder();
        var comparisonBytes = BytesBuilder();
        var entries = <String, Frame>{};

        void addFrame(String key, dynamic val, [bool keep = false]) {
          var frameBytes = Frame(key, val).toBytes(null, null);
          if (keep) {
            entries[key] = Frame(key, val,
                length: frameBytes.length, offset: bytes.length);
            comparisonBytes.add(frameBytes);
          } else {
            entries.remove(key);
          }
          bytes.add(frameBytes);
        }

        for (var i = 0; i < 1000; i++) {
          for (var key in testMap.keys) {
            addFrame(key, testMap[key]);
            addFrame(key, null);
          }
        }

        for (var key in testMap.keys) {
          addFrame(key, 12345);
          addFrame(key, null);
          addFrame(key, 'This is a test');
          addFrame(key, testMap[key], true);
        }

        var boxFile = await getTempFile();
        await boxFile.writeAsBytes(bytes.toBytes());

        var syncedFile = SyncedFile(boxFile.path);
        await syncedFile.open();
        var backend = StorageBackendVm(syncedFile, null);

        await backend.compact(entries.values);

        var compactedBytes = await File(backend.path).readAsBytes();
        expect(compactedBytes, comparisonBytes.toBytes());

        await backend.close();
      });

      test('throws error if corrupted', () async {
        var bytes = BytesBuilder();
        var boxFile = await getTempFile(); 
        var syncedFile = SyncedFile(boxFile.path);
        await syncedFile.open();

        var box = BoxImplVm(
            HiveImpl(), path.basename(boxFile.path), BoxOptions(), syncedFile);
        await box.put('test', true);
        await box.put('test2', 'hello');
        await box.put('test', 'world');

        await syncedFile.truncate(await boxFile.length() - 1);

        expect(() => box.compact(), throwsHiveError(['unexpected eof']));
      });
    });*/

    test('.clear()', () async {
      final writeRaf = MockRandomAccessFile();
      when(() => writeRaf.truncate(0))
          .thenAnswer((i) => Future.value(writeRaf));
      when(() => writeRaf.setPosition(0))
          .thenAnswer((i) => Future.value(writeRaf));
      final backend = _getBackend(writeRaf: writeRaf);
      backend.writeOffset = 111;

      await backend.clear();
      verify(() => writeRaf.truncate(0));
      verify(() => writeRaf.setPosition(0));
      expect(backend.writeOffset, 0);
    });

    test('.close()', () async {
      final readRaf = MockRandomAccessFile();
      final writeRaf = MockRandomAccessFile();
      final lockRaf = MockRandomAccessFile();
      final lockFile = MockFile();

      returnFutureVoid(when(readRaf.close));
      returnFutureVoid(when(writeRaf.close));
      returnFutureVoid(when(lockRaf.close));
      when(lockFile.delete).thenAnswer((i) => Future.value(lockFile));

      final backend = _getBackend(
        lockFile: lockFile,
        readRaf: readRaf,
        writeRaf: writeRaf,
      );
      backend.lockRaf = lockRaf;

      await backend.close();
      verifyInOrder([
        readRaf.close,
        writeRaf.close,
        lockRaf.close,
        lockFile.delete,
      ]);
    });

    test('.deleteFromDisk()', () async {
      final readRaf = MockRandomAccessFile();
      final writeRaf = MockRandomAccessFile();
      final lockRaf = MockRandomAccessFile();
      final lockFile = MockFile();
      final file = MockFile();

      returnFutureVoid(when(readRaf.close));
      returnFutureVoid(when(writeRaf.close));
      returnFutureVoid(when(lockRaf.close));
      when(lockFile.delete).thenAnswer((i) => Future.value(lockFile));
      when(file.delete).thenAnswer((i) => Future.value(file));

      final backend = _getBackend(
        file: file,
        lockFile: lockFile,
        readRaf: readRaf,
        writeRaf: writeRaf,
      );
      backend.lockRaf = lockRaf;

      await backend.deleteFromDisk();
      verifyInOrder([
        readRaf.close,
        writeRaf.close,
        lockRaf.close,
        lockFile.delete,
        file.delete,
      ]);
    });
  });
}
