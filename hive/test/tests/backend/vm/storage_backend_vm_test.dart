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
import 'package:meta/meta.dart';
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

@immutable
class _CountingRandomAccessFile extends Fake implements RandomAccessFile {
  final RandomAccessFile _inner;
  final readLengths = <int>[];
  final readSyncLengths = <int>[];

  _CountingRandomAccessFile(this._inner);

  @override
  Future<RandomAccessFile> setPosition(int position) =>
      _inner.setPosition(position);

  @override
  void setPositionSync(int position) => _inner.setPositionSync(position);

  @override
  Future<Uint8List> read(int count) {
    readLengths.add(count);
    return _inner.read(count);
  }

  @override
  Uint8List readSync(int count) {
    readSyncLengths.add(count);
    return _inner.readSync(count);
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
        when(
          () => helper.framesFromFile(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((i) => Future.value(recoveryOffset));
        when(
          () => helper.keysFromFile(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((i) => Future.value(recoveryOffset));
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

      test(
        'activates 16 KB read-ahead on sequential reads and refills across windows',
        () async {
          final frames = [
            for (var i = 0; i < 550; i++)
              Frame('k$i', 'value_${i}_${'a' * 40}'),
          ];
          final bytes = getFrameBytes(frames);
          expect(bytes.length, greaterThan(16384 * 2));
          final countingRaf =
              _CountingRandomAccessFile(await getTempRaf(bytes));
          final backend = _getBackend(readRaf: countingRaf)
            ..registry = TypeRegistryImpl.nullImpl;

          expect(await backend.readValue(frames[0]), 'value_0_${'a' * 40}');
          expect(countingRaf.readLengths, [frames[0].length]);

          expect(await backend.readValue(frames[1]), 'value_1_${'a' * 40}');
          expect(countingRaf.readLengths, [frames[0].length, 16384]);

          for (var i = 2; i < frames.length; i++) {
            expect(
              await backend.readValue(frames[i]),
              'value_${i}_${'a' * 40}',
            );
          }

          expect(countingRaf.readLengths.first, frames[0].length);
          expect(countingRaf.readLengths.skip(1), everyElement(16384));
          expect(countingRaf.readLengths.length, inInclusiveRange(3, 5));

          await countingRaf.close();
        },
      );

      test(
        'uses sync IO in isolated mode and detaches verbatim bytes',
        () async {
          final frames = [
            for (var i = 0; i < 3; i++) Frame('k$i', 'iso_$i'),
          ];
          final countingRaf = _CountingRandomAccessFile(
            await getTempRaf(getFrameBytes(frames)),
          );

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
          final frame1Bytes =
              await backend.readValue(frames[1], verbatim: true) as Uint8List;
          final frame2Bytes =
              await backend.readValue(frames[2], verbatim: true) as Uint8List;

          expect(frame1Bytes.buffer.lengthInBytes, frame1Bytes.length);
          expect(frame2Bytes.buffer.lengthInBytes, frame2Bytes.length);
          expect(countingRaf.readLengths, isEmpty);
          expect(countingRaf.readSyncLengths, [frames[0].length, 16384]);

          await countingRaf.close();
        },
      );

      test(
        'skips read-ahead on random reads, out-of-window jumps, and >16 KB frames',
        () async {
          final largePayload = 'L' * 20000;
          final frames = [
            Frame('k0', 'small_0'),
            Frame('k1', 'small_1'),
            Frame('k2', largePayload),
            Frame('k3', 'small_3'),
            Frame('k4', 'small_4'),
          ];
          final countingRaf = _CountingRandomAccessFile(
            await getTempRaf(getFrameBytes(frames)),
          );
          final backend = _getBackend(readRaf: countingRaf)
            ..registry = TypeRegistryImpl.nullImpl;

          expect(await backend.readValue(frames[0]), 'small_0');
          expect(await backend.readValue(frames[3]), 'small_3');
          expect(await backend.readValue(frames[1]), 'small_1');
          expect(countingRaf.readLengths, [
            frames[0].length,
            frames[3].length,
            frames[1].length,
          ]);

          countingRaf.readLengths.clear();
          expect(await backend.readValue(frames[0]), 'small_0');
          expect(await backend.readValue(frames[1]), 'small_1');
          expect(await backend.readValue(frames[2]), largePayload);
          expect(await backend.readValue(frames[3]), 'small_3');
          expect(await backend.readValue(frames[4]), 'small_4');
          expect(await backend.readValue(frames[0]), 'small_0');
          expect(countingRaf.readLengths, [
            frames[0].length,
            16384,
            frames[2].length,
            16384,
            frames[0].length,
          ]);

          await countingRaf.close();
        },
      );

      test(
        'throws HiveError and resets cache on truncated read-ahead refill',
        () async {
          final frames = [
            Frame('k0', 'v0'),
            Frame('k1', 'v1_longer_payload'),
          ];
          final fullBytes = getFrameBytes(frames);
          final countingRaf = _CountingRandomAccessFile(
            await getTempRaf(fullBytes.sublist(0, fullBytes.length - 3)),
          );
          final backend = _getBackend(readRaf: countingRaf)
            ..registry = TypeRegistryImpl.nullImpl;

          expect(await backend.readValue(frames[0]), 'v0');
          await expectLater(
            () => backend.readValue(frames[1]),
            throwsHiveError(['corrupted']),
          );
          expect(await backend.readValue(frames[0]), 'v0');
          expect(countingRaf.readLengths, [
            frames[0].length,
            16384,
            frames[0].length,
          ]);

          await countingRaf.close();
        },
      );

      test('invalidates read-ahead cache on compact() and clear()', () async {
        final dir = await getTempDir();
        addTearDown(() async {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        });
        final file = File(path.join(dir.path, 'invalidation_test.hive'));
        final lockFile = File(path.join(dir.path, 'invalidation_test.lock'));
        await file.create(recursive: true);

        final backend = StorageBackendVm(file, lockFile, false, null, null);
        await backend.open();
        await backend.initialize(
          TypeRegistryImpl.nullImpl,
          Keystore.debug(),
          true,
        );
        try {
          final f0 = Frame('k0', 'keep_0');
          final f1 = Frame('k1', 'drop_medium_key');
          final f2 = Frame('k2', 'keep_2_longer_payload');
          final f3 = Frame('k3', 'keep_3');
          await backend.writeFrames([f0, f1, f2, f3]);

          // Warm read-ahead starting at f1.offset so the window spans f1..f3.
          expect(await backend.readValue(f0), 'keep_0');
          expect(await backend.readValue(f1), 'drop_medium_key');

          await backend.compact([f0, f2, f3]);

          final countingRaf = _CountingRandomAccessFile(backend.readRaf);
          backend.readRaf = countingRaf;

          // f2 shifted to f1's old offset inside the pre-compact window.
          expect(await backend.readValue(f2), 'keep_2_longer_payload');
          expect(await backend.readValue(f0), 'keep_0');
          expect(await backend.readValue(f2), 'keep_2_longer_payload');
          expect(await backend.readValue(f3), 'keep_3');
          expect(countingRaf.readLengths, [f2.length, f0.length, 16384]);

          await backend.clear();

          final newFrames = [
            Frame('k0', 'keep_0'),
            Frame('k1', 'new_1'),
            Frame('k2', 'new_2'),
          ];
          await backend.writeFrames(newFrames);

          // newFrames[1] shares pre-clear f2's offset inside the buffer.
          expect(await backend.readValue(newFrames[1]), 'new_1');
          expect(await backend.readValue(newFrames[2]), 'new_2');
          expect(countingRaf.readLengths, [
            f2.length,
            f0.length,
            16384,
            newFrames[1].length,
            16384,
          ]);
        } finally {
          await backend.close();
        }
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
