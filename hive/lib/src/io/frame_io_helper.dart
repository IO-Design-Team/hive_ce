import 'dart:io';
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
      return await _readKeysFromRaf(
        raf,
        await raf.length(),
        keystore,
        cipher,
        keyCrc,
      );
    } finally {
      await raf.close();
    }
  }

  /// Not part of public API
  Future<int> keysFromRaf(
    RandomAccessFile raf,
    int fileLength,
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc,
  ) async {
    if (fileLength <= 0) return -1;
    await raf.setPosition(0);
    return await _readKeysFromRaf(raf, fileLength, keystore, cipher, keyCrc);
  }

  Future<int> _readKeysFromRaf(
    RandomAccessFile raf,
    int fileLength,
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc,
  ) {
    final fileReader = fileLength > _bigBoxChunkSize
        ? BufferedFileReader(raf, _bigBoxChunkSize)
        : BufferedFileReader(raf);
    return _KeyReader(fileReader).readKeys(keystore, cipher, keyCrc);
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

  /// Not part of public API
  Future<int> framesFromRaf(
    RandomAccessFile raf,
    int fileLength,
    Keystore keystore,
    TypeRegistry registry,
    HiveCipher? cipher,
    int? keyCrc, {
    bool verbatim = false,
  }) async {
    if (fileLength <= 0) return -1;
    await raf.setPosition(0);
    final bytes = Uint8List(fileLength);
    var offset = 0;
    while (offset < fileLength) {
      final read = await raf.readInto(bytes, offset, fileLength);
      if (read == 0) break;
      offset += read;
    }
    final data =
        offset == fileLength ? bytes : Uint8List.sublistView(bytes, 0, offset);
    return framesFromBytes(
      data,
      keystore,
      registry,
      cipher,
      keyCrc,
      verbatim: verbatim,
    );
  }
}

class _KeyReader {
  final BufferedFileReader fileReader;

  late BinaryReaderImpl _reader;

  _KeyReader(this.fileReader);

  Future<int> readKeys(
    Keystore keystore,
    HiveCipher? cipher,
    int? keyCrc,
  ) async {
    await _load(4);
    while (true) {
      final frameOffset = fileReader.offset;

      if (_reader.availableBytes < 4) {
        final available = await _load(4);
        if (available == 0) {
          break;
        } else if (available < 4) {
          return frameOffset;
        }
      }

      final frameLength = _reader.peekUint32();
      if (_reader.availableBytes < frameLength) {
        final available = await _load(frameLength);
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
    }

    return -1;
  }

  Future<int> _load(int bytes) async {
    final loadedBytes = await fileReader.loadBytes(bytes);
    final buffer = fileReader.peekBytes(loadedBytes);
    _reader = BinaryReaderImpl(buffer, TypeRegistryImpl.nullImpl);

    return loadedBytes;
  }
}
