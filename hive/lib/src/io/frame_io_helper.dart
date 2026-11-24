import 'dart:io';
import 'dart:math';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/io/buffered_file_reader.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:meta/meta.dart';

/// Not part of public API
class FrameIoHelper {
  static const _maxChunkSize = 1 << 20;

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
      if (fileLength < 8) return 0;

      final fileReader = BufferedFileReader(
        raf,
        min(fileLength, _maxChunkSize),
      );
      var reader = await _loadReader(fileReader, registry, 4);

      while (fileReader.offset < fileLength) {
        final frameOffset = fileReader.offset;

        if (reader.availableBytes < 4) {
          reader = await _loadReader(fileReader, registry, 4);
          if (reader.availableBytes < 4) return frameOffset;
        }

        final frameLength = reader.peekUint32();
        if (frameLength < 8 || frameLength > fileLength - frameOffset) {
          return frameOffset;
        }

        if (reader.availableBytes < frameLength) {
          reader = await _loadReader(fileReader, registry, frameLength);
          if (reader.availableBytes < frameLength) return frameOffset;
        }

        final frame = reader.readFrame(
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
    } finally {
      await raf.close();
    }
  }

  Future<BinaryReaderImpl> _loadReader(
    BufferedFileReader fileReader,
    TypeRegistry registry,
    int bytes,
  ) async {
    final loadedBytes = await fileReader.loadBytes(bytes);
    return BinaryReaderImpl(fileReader.peekBytes(loadedBytes), registry);
  }
}
