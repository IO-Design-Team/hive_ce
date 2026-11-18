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
      // [cipher] and [keyCrc] are applied when a value is read. Listing keys
      // does not checksum value bytes.
      return await _KeyReader(fileReader).readKeys(keystore, length);
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
  /// No value is checksummed until it is read.
  static const _largeFrameBytes = 64 * 1024;

  /// Most bytes a key can occupy: type byte, length byte, and 255 UTF-8 bytes.
  static const _maxKeyBytes = 1 + 1 + 255;

  static final _empty = Uint8List(0);

  final BufferedFileReader fileReader;

  late BinaryReaderImpl _reader;

  _KeyReader(this.fileReader);

  Future<int> readKeys(Keystore keystore, int fileLength) async {
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

      final headerLength = min(frameLength, 4 + _maxKeyBytes);
      if (_reader.availableBytes < headerLength) {
        final large = frameLength > _largeFrameBytes;
        final available = await _load(
          headerLength,
          // A large value is seeked past. A small one stays in the read-ahead
          // buffer so the following frames do not each cost a seek.
          maxRead: large ? headerLength - _reader.availableBytes : null,
        );
        if (available < headerLength) return frameOffset;
      }

      final frame = _readKeyOnly(frameOffset, frameLength);
      if (frame == null) return frameOffset;

      keystore.insert(frame, notify: false);
      await fileReader.skipAhead(frameLength);
      _reader = BinaryReaderImpl(_empty, TypeRegistryImpl.nullImpl);
    }

    return -1;
  }

  Frame? _readKeyOnly(int frameOffset, int frameLength) {
    try {
      final start = _reader.usedBytes;
      final length = _reader.readUint32();
      if (length != frameLength) return null;
      final key = _reader.readKey();
      // The checksum is the last 4 bytes. A body that ends at the key is a
      // tombstone; anything after the key is a value and is not hashed here.
      final consumed = _reader.usedBytes - start;
      if (consumed > frameLength - 4) return null;
      if (consumed == frameLength - 4) {
        return Frame.deleted(key, length: frameLength);
      }
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
