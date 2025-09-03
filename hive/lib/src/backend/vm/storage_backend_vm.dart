import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/backend/lock_props.dart';
import 'package:hive_ce/src/backend/storage_backend.dart';
import 'package:hive_ce/src/backend/vm/read_write_sync.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/io/buffered_file_reader.dart';
import 'package:hive_ce/src/io/buffered_file_writer.dart';
import 'package:hive_ce/src/io/frame_io_helper.dart';
import 'package:hive_ce/src/util/debug_utils.dart';
import 'package:meta/meta.dart';

/// Storage backend for the Dart VM
class StorageBackendVm extends StorageBackend {
  /// Warning for existing lock of unmatched isolation
  @visibleForTesting
  static const unmatchedIsolationWarning = '''
⚠️ WARNING: HIVE MULTI-ISOLATE RISK DETECTED ⚠️

You are opening this box with Hive, but this box was previously opened with
IsolatedHive. This can lead to DATA CORRUPTION as Hive boxes are not designed
for concurrent access across isolates. Each isolate would maintain its own box
cache, potentially causing data inconsistency and corruption.

RECOMMENDED ACTIONS:
- ALWAYS use IsolatedHive to perform box operations when working with multiple
  isolates
''';

  final File _file;
  final File _lockFile;
  final bool _crashRecovery;
  final HiveCipher? _cipher;
  final FrameIoHelper _frameHelper;

  final ReadWriteSync _sync;

  /// Not part of public API
  ///
  /// Not `late final` for testing
  @visibleForTesting
  late RandomAccessFile readRaf;

  /// Not part of public API
  ///
  /// Not `late final` for testing
  @visibleForTesting
  late RandomAccessFile writeRaf;

  /// Not part of public API
  @visibleForTesting
  late RandomAccessFile lockRaf;

  /// Not part of public API
  @visibleForTesting
  var writeOffset = 0;

  /// Not part of public API
  @visibleForTesting
  late final TypeRegistry registry;

  var _compactionScheduled = false;

  /// Not part of public API
  StorageBackendVm(
    this._file,
    this._lockFile,
    this._crashRecovery,
    this._cipher,
  )   : _frameHelper = FrameIoHelper(),
        _sync = ReadWriteSync();

  /// Not part of public API
  StorageBackendVm.debug(
    this._file,
    this._lockFile,
    this._crashRecovery,
    this._cipher,
    this._frameHelper,
    this._sync,
  );

  @override
  String get path => _file.path;

  @override
  var supportsCompaction = true;

  /// Not part of public API
  Future open() async {
    readRaf = await _file.open();
    writeRaf = await _file.open(mode: FileMode.writeOnlyAppend);
    writeOffset = await writeRaf.length();
  }

  @override
  Future<void> initialize(
    TypeRegistry registry,
    Keystore keystore,
    bool lazy, {
    bool isolated = false,
  }) async {
    this.registry = registry;

    if (_lockFile.existsSync()) {
      late final LockProps props;
      try {
        props = LockProps.fromJson(jsonDecode(_lockFile.readAsStringSync()));
      } catch (_) {
        props = LockProps();
      }
      if (props.isolated && !isolated) {
        debugPrint(unmatchedIsolationWarning);
      }
    }

    lockRaf = await _lockFile.open(mode: FileMode.write);
    lockRaf.writeStringSync(jsonEncode(LockProps(isolated: isolated)));
    lockRaf.flushSync();
    await lockRaf.lock();

    int recoveryOffset;
    if (!lazy) {
      recoveryOffset = await _frameHelper.framesFromFile(
        path,
        keystore,
        registry,
        _cipher,
        verbatim: isolated,
      );
    } else {
      recoveryOffset = await _frameHelper.keysFromFile(path, keystore, _cipher);
    }

    if (recoveryOffset != -1) {
      if (_crashRecovery) {
        debugPrint('Recovering corrupted box.');
        await writeRaf.truncate(recoveryOffset);
        await writeRaf.setPosition(recoveryOffset);
        writeOffset = recoveryOffset;
      } else {
        throw HiveError('Wrong checksum in hive file. Box may be corrupted.');
      }
    }
  }

  @override
  Future<dynamic> readValue(Frame frame, {bool verbatim = false}) {
    return _sync.syncRead(() async {
      await readRaf.setPosition(frame.offset);

      final bytes = await readRaf.read(frame.length!);

      final reader = BinaryReaderImpl(bytes, registry);
      final readFrame =
          reader.readFrame(cipher: _cipher, lazy: false, verbatim: verbatim);

      if (readFrame == null) {
        throw HiveError(
          'Could not read value from box. Maybe your box is corrupted.',
        );
      }

      return readFrame.value;
    });
  }

  @override
  Future<void> writeFrames(List<Frame> frames, {bool verbatim = false}) {
    return _sync.syncWrite(() async {
      final writer = BinaryWriterImpl(registry);

      for (final frame in frames) {
        frame.length =
            writer.writeFrame(frame, cipher: _cipher, verbatim: verbatim);
      }

      try {
        await writeRaf.writeFrom(writer.toBytes());
      } catch (e) {
        await writeRaf.setPosition(writeOffset);
        rethrow;
      }

      for (final frame in frames) {
        frame.offset = writeOffset;
        writeOffset += frame.length!;
      }
    });
  }

  @override
  Future<void> compact(Iterable<Frame> frames) {
    if (_compactionScheduled) return Future.value();
    _compactionScheduled = true;

    return _sync.syncReadWrite(() async {
      await readRaf.setPosition(0);
      final reader = BufferedFileReader(readRaf);

      final fileDirectory = path.substring(0, path.length - 5);
      final compactFile = File('$fileDirectory.hivec');
      final compactRaf = await compactFile.open(mode: FileMode.write);
      final writer = BufferedFileWriter(compactRaf);

      final sortedFrames = frames.toList();
      sortedFrames.sort((a, b) => a.offset.compareTo(b.offset));
      try {
        for (final frame in sortedFrames) {
          if (frame.offset == -1) continue; // Frame has not been written yet
          if (frame.offset != reader.offset) {
            final skip = frame.offset - reader.offset;
            if (reader.remainingInBuffer < skip) {
              if (await reader.loadBytes(skip) < skip) {
                throw HiveError('Could not compact box: Unexpected EOF.');
              }
            }
            reader.skip(skip);
          }

          if (reader.remainingInBuffer < frame.length!) {
            if (await reader.loadBytes(frame.length!) < frame.length!) {
              throw HiveError('Could not compact box: Unexpected EOF.');
            }
          }
          await writer.write(reader.viewBytes(frame.length!));
        }
        await writer.flush();
      } finally {
        await compactRaf.close();
      }

      await readRaf.close();
      await writeRaf.close();

      try {
        await compactFile.rename(path);
      } catch (e) {
        await compactFile.delete();
        rethrow;
      } finally {
        await open();
        _compactionScheduled = false;
      }

      var offset = 0;
      for (final frame in sortedFrames) {
        if (frame.offset == -1) continue;
        frame.offset = offset;
        offset += frame.length!;
      }
    });
  }

  @override
  Future<void> clear() {
    return _sync.syncReadWrite(() async {
      await writeRaf.truncate(0);
      await writeRaf.setPosition(0);
      writeOffset = 0;
    });
  }

  Future _closeInternal() async {
    await readRaf.close();
    await writeRaf.close();

    await lockRaf.close();
    await _lockFile.delete();
  }

  @override
  Future<void> close() {
    return _sync.syncReadWrite(_closeInternal);
  }

  @override
  Future<void> deleteFromDisk() {
    return _sync.syncReadWrite(() async {
      await _closeInternal();
      await _file.delete();
    });
  }

  @override
  Future<void> flush() {
    return _sync.syncWrite(() async {
      await writeRaf.flush();
    });
  }
}
