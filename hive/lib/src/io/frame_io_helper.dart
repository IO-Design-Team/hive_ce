import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/frame_helper.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/io/buffered_file_reader.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:meta/meta.dart';

/// Not part of public API
class FrameIoHelper extends FrameHelper {
  static const _bigBoxChunkSize = 1 << 20;

  /// Not part of public API
  @visibleForTesting
  Future<RandomAccessFile> openFile(String path) {
    return File(path).open();
  }

  /// Not part of public API
  Future<int> keysFromFile(
    String path,
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc,
  ) =>
      _readFromFile(
        path,
        keystore,
        TypeRegistryImpl.nullImpl,
        cipher,
        keyCrc,
        lazy: true,
      );

  /// Not part of public API
  Future<int> framesFromFile(
    String path,
    Keystore keystore,
    TypeRegistry registry,
    HiveCipher? cipher,
    int? keyCrc, {
    bool verbatim = false,
  }) =>
      _readFromFile(
        path,
        keystore,
        registry,
        cipher,
        keyCrc,
        lazy: false,
        verbatim: verbatim,
      );

  Future<int> _readFromFile(
    String path,
    Keystore keystore,
    TypeRegistry registry,
    HiveCipher? cipher,
    int? keyCrc, {
    required bool lazy,
    bool verbatim = false,
  }) async {
    final raf = await openFile(path);
    try {
      final fileLength = await raf.length();
      if (fileLength == 0) return -1;

      final chunkSize = lazy
          ? (fileLength > _bigBoxChunkSize
              ? _bigBoxChunkSize
              : min(fileLength, BufferedFileReader.defaultChunkSize))
          : min(fileLength, _bigBoxChunkSize);
      final fileReader = BufferedFileReader(raf, chunkSize);
      return await _FrameReader(fileReader, registry, fileLength).readFrames(
        keystore,
        cipher,
        keyCrc,
        lazy: lazy,
        verbatim: verbatim,
      );
    } finally {
      await raf.close();
    }
  }
}

class _FrameReader {
  final BufferedFileReader fileReader;
  final TypeRegistry registry;
  final int fileLength;

  BinaryReaderImpl _reader;

  _FrameReader(this.fileReader, this.registry, this.fileLength)
      : _reader = BinaryReaderImpl(Uint8List(0), registry);

  Future<int> readFrames(
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc, {
    required bool lazy,
    bool verbatim = false,
  }) async {
    while (true) {
      final frameOffset = fileReader.offset;

      if (_reader.availableBytes < 4) {
        if (_reader.availableBytes == 0 && frameOffset == fileLength) {
          break;
        }
        final available = await _load(4);
        if (available == 0) {
          break;
        } else if (available < 4) {
          return frameOffset;
        }
      }

      final frameLength = _reader.peekUint32();
      if (frameLength < 8 || frameLength > fileLength - frameOffset) {
        return frameOffset;
      }

      if (_reader.availableBytes < frameLength) {
        final available = await _load(frameLength);
        if (available < frameLength) return frameOffset;
      }

      final frame = _reader.readFrame(
        cipher: cipher,
        keyCrc: keyCrc,
        lazy: lazy,
        frameOffset: frameOffset,
        verbatim: verbatim,
      );
      if (frame == null) return frameOffset;

      keystore.insert(frame, notify: false);

      fileReader.skip(frameLength);
    }

    return -1;
  }

  Future<int> _load(int bytes) async {
    final loadedBytes = await fileReader.loadBytes(bytes);
    final buffer = fileReader.peekBytes(loadedBytes);
    _reader = BinaryReaderImpl(buffer, registry);

    return loadedBytes;
  }
}
