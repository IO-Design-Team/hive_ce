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
  /// If [verify] is false, only frame headers are read and values are skipped
  Future<int> keysFromFile(
    String path,
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc, {
    bool verify = true,
  }) async {
    final raf = await openFile(path);
    try {
      final fileLength = await raf.length();
      final fileReader = verify && fileLength > _bigBoxChunkSize
          ? BufferedFileReader(raf, _bigBoxChunkSize)
          : BufferedFileReader(raf);
      return await _KeyReader(fileReader, fileLength)
          .readKeys(keystore, cipher, keyCrc, verify: verify);
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
  /// Frame length + key type + string key length + string key
  static const _maxHeaderLength = 4 + 1 + 1 + 255;

  final BufferedFileReader fileReader;
  final int fileLength;

  late BinaryReaderImpl _reader;

  _KeyReader(this.fileReader, this.fileLength);

  Future<int> readKeys(
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc, {
    required bool verify,
  }) async {
    await _load(4);
    while (true) {
      final frameOffset = fileReader.offset;
      final remaining = fileLength - frameOffset;
      if (remaining == 0) return -1;
      if (remaining < 4) return frameOffset;

      if (_reader.availableBytes < 4) await _load(4);
      final frameLength = _reader.peekUint32();
      if (frameLength < 8 || frameLength > remaining) return frameOffset;

      final headerLength =
          verify ? frameLength : min(frameLength - 4, _maxHeaderLength);
      if (_reader.availableBytes < headerLength) await _load(headerLength);

      final frameStart = _reader.usedBytes;
      final frame = verify
          ? _reader.readFrame(cipher: cipher, keyCrc: keyCrc, lazy: true)
          : _readFrameHeader(frameLength);
      if (frame == null) return frameOffset;

      keystore.insert(frame..offset = frameOffset, notify: false);

      final unread = frameLength - (_reader.usedBytes - frameStart);
      if (_reader.availableBytes >= unread) {
        _reader.skip(unread);
        fileReader.skip(frameLength);
      } else {
        await fileReader.seek(frameLength);
        await _load(4);
      }
    }
  }

  Frame? _readFrameHeader(int frameLength) {
    final frameStart = _reader.usedBytes;
    _reader.skip(4);

    final dynamic key;
    try {
      key = _reader.readKey();
    } catch (_) {
      return null;
    }

    final valueLength = frameLength - 4 - (_reader.usedBytes - frameStart);
    if (valueLength < 0) return null;

    return valueLength == 0
        ? Frame.deleted(key, length: frameLength)
        : Frame.lazy(key, length: frameLength);
  }

  Future<int> _load(int bytes) async {
    final loadedBytes = await fileReader.loadBytes(bytes);
    final buffer = fileReader.peekBytes(loadedBytes);
    _reader = BinaryReaderImpl(buffer, TypeRegistryImpl.nullImpl);

    return loadedBytes;
  }
}
