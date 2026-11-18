import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/binary/frame_helper.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/io/buffered_file_reader.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:meta/meta.dart';

/// Not part of public API
class FrameIoHelper extends FrameHelper {
  /// Not part of public API
  @visibleForTesting
  Future<RandomAccessFile> openFile(String path) {
    return File(path).open();
  }

  /// Not part of public API
  @visibleForTesting
  Future<List<int>> readFile(String path) {
    return File(path).readAsBytes();
  }

  /// Not part of public API
  ///
  /// Only the first frame is checksum verified to detect a wrong cipher. The
  /// remaining frames are verified when their values are read.
  Future<int> keysFromFile(
    String path,
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc,
  ) async {
    final raf = await openFile(path);
    try {
      final fileReader = BufferedFileReader(raf);
      return await _KeyReader(fileReader, await raf.length())
          .readKeys(keystore, cipher, keyCrc);
    } finally {
      await raf.close();
    }
  }

  /// Not part of public API
  Future<int> framesFromFile(
    String path,
    Keystore keystore,
    TypeRegistry registry,
    HiveCipher? cipher,
    int? keyCrc, {
    bool verbatim = false,
  }) async {
    final bytes = await readFile(path);
    return framesFromBytes(
      bytes as Uint8List,
      keystore,
      registry,
      cipher,
      keyCrc,
      verbatim: verbatim,
    );
  }
}

class _KeyReader {
  /// Frame length + key type + string key length + string key
  static const _maxHeaderLength = 4 + 1 + 1 + 255;

  final BufferedFileReader fileReader;
  final int fileLength;

  var _reader = BinaryReaderImpl(Uint8List(0), TypeRegistryImpl.nullImpl);

  _KeyReader(this.fileReader, this.fileLength);

  Future<int> readKeys(
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc,
  ) async {
    while (true) {
      final frameOffset = fileReader.offset;
      final remaining = fileLength - frameOffset;
      if (remaining == 0) break;
      if (remaining < 4) return frameOffset;

      if (_reader.availableBytes < 4) await _load(4);
      final frameLength = _reader.peekUint32();
      if (frameLength < 8 || frameLength > remaining) return frameOffset;

      final verify = frameOffset == 0;
      final headerLength =
          verify ? frameLength : min(frameLength - 4, _maxHeaderLength);
      if (_reader.availableBytes < headerLength) await _load(headerLength);

      final frameStart = _reader.usedBytes;
      final frame = verify
          ? _reader.readFrame(
              cipher: cipher,
              keyCrc: keyCrc,
              lazy: true,
              frameOffset: frameOffset,
            )
          : _readFrameHeader(frameLength, frameOffset);
      if (frame == null) return frameOffset;

      keystore.insert(frame, notify: false);

      final unread = frameLength - (_reader.usedBytes - frameStart);
      if (_reader.availableBytes >= unread) {
        _reader.skip(unread);
        fileReader.skip(frameLength);
      } else {
        await fileReader.skipFile(frameLength);
        _reader = BinaryReaderImpl(Uint8List(0), TypeRegistryImpl.nullImpl);
      }
    }

    return -1;
  }

  Frame? _readFrameHeader(int frameLength, int frameOffset) {
    final keyStart = _reader.usedBytes + 4;
    _reader.skip(4);

    final dynamic key;
    try {
      key = _reader.readKey();
    } catch (_) {
      return null;
    }

    final valueLength = frameLength - 8 - (_reader.usedBytes - keyStart);
    if (valueLength < 0) return null;

    final frame = valueLength == 0
        ? Frame.deleted(key, length: frameLength)
        : Frame.lazy(key, length: frameLength);
    return frame..offset = frameOffset;
  }

  Future<void> _load(int bytes) async {
    final loadedBytes = await fileReader.loadBytes(bytes);
    _reader = BinaryReaderImpl(
      fileReader.peekBytes(loadedBytes),
      TypeRegistryImpl.nullImpl,
    );
  }
}
