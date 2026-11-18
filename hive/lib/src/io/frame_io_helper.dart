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
  Future<int> keysFromFile(
    String path,
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc,
  ) async {
    final raf = await openFile(path);
    try {
      final length = await raf.length();
      final fileReader = length > _bigBoxChunkSize
          ? BufferedFileReader(raf, _bigBoxChunkSize)
          : BufferedFileReader(raf);
      return await _KeyReader(fileReader).readKeys(
        keystore,
        cipher,
        keyCrc,
        length,
      );
    } finally {
      await raf.close();
    }
  }

  static const _bigBoxChunkSize = 1 << 20;

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
  /// Values larger than this are not read while opening a lazy box. The frame
  /// length is at the front, so the key can be parsed and the rest skipped.
  /// The checksum is checked when the value is read. The first frame is always
  /// checked so the wrong cipher still fails at open.
  static const _largeFrameBytes = 64 * 1024;

  /// Most bytes a key can occupy: type byte, length byte, and 255 UTF-8 bytes.
  static const _maxKeyBytes = 1 + 1 + 255;

  static final _empty = Uint8List(0);

  final BufferedFileReader fileReader;

  late BinaryReaderImpl _reader;

  _KeyReader(this.fileReader);

  Future<int> readKeys(
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc,
    int fileLength,
  ) async {
    var verifiedChecksum = false;

    // Read the length only. Filling the buffer here would pull in a large
    // value before its size is known.
    await _load(4, maxRead: 4);
    while (true) {
      final frameOffset = fileReader.offset;

      if (_reader.availableBytes < 4) {
        final available = await _load(4, maxRead: 4);
        if (available == 0) {
          break;
        } else if (available < 4) {
          return frameOffset;
        }
      }

      final frameLength = _reader.peekUint32();
      if (frameLength < 8 || frameOffset + frameLength > fileLength) {
        return frameOffset;
      }

      final buffered = _reader.availableBytes >= frameLength;
      final large = frameLength > _largeFrameBytes;
      if (large && !buffered && verifiedChecksum) {
        final headerLength = min(frameLength, 4 + _maxKeyBytes);
        if (_reader.availableBytes < headerLength) {
          final available = await _load(
            headerLength,
            maxRead: headerLength - _reader.availableBytes,
          );
          if (available < headerLength) return frameOffset;
        }

        final frame = _readKeyOnly(frameOffset, frameLength);
        if (frame != null) {
          keystore.insert(frame, notify: false);
          await fileReader.skipAhead(frameLength);
          _reader = BinaryReaderImpl(_empty, TypeRegistryImpl.nullImpl);
          continue;
        }
      }

      if (_reader.availableBytes < frameLength) {
        final available = await _load(
          frameLength,
          // Don't prefetch the next large value just to checksum this one.
          maxRead: large ? frameLength - _reader.availableBytes : null,
        );
        if (available < frameLength) return frameOffset;
      }

      final frame = _reader.readFrame(
        cipher: cipher,
        keyCrc: keyCrc,
        lazy: true,
        frameOffset: frameOffset,
      );
      if (frame == null) return frameOffset;

      keystore.insert(frame, notify: false);
      fileReader.skip(frameLength);
      verifiedChecksum = true;
    }

    return -1;
  }

  Frame? _readKeyOnly(int frameOffset, int frameLength) {
    try {
      final length = _reader.readUint32();
      if (length != frameLength) return null;
      final key = _reader.readKey();
      return Frame.lazy(key, length: frameLength, offset: frameOffset);
    } on HiveError {
      return null;
    } on RangeError {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<int> _load(int bytes, {int? maxRead}) async {
    final loadedBytes = await fileReader.loadBytes(bytes, maxRead: maxRead);
    final buffer = fileReader.peekBytes(loadedBytes);
    _reader = BinaryReaderImpl(buffer, TypeRegistryImpl.nullImpl);

    return loadedBytes;
  }
}
