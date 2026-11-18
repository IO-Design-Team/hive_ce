import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Not part of public API
class BufferedFileReader {
  /// Not part of public API
  @visibleForTesting
  static const defaultChunkSize = 1000 * 64;

  /// Not part of public API
  @visibleForTesting
  final RandomAccessFile file;

  /// Not part of public API
  @visibleForTesting
  Uint8List buffer;

  final int _chunkSize;

  var _bufferSize = 0;
  var _bufferOffset = 0;
  var _fileOffset = 0;

  /// Not part of public API
  int get remainingInBuffer => _bufferSize - _bufferOffset;

  /// Not part of public API
  int get offset => _fileOffset - remainingInBuffer;

  /// Not part of public API
  BufferedFileReader(this.file, [int bufferSize = defaultChunkSize])
      : buffer = Uint8List(bufferSize),
        _chunkSize = bufferSize;

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void skip(int bytes) {
    assert(bytes >= 0 && remainingInBuffer >= bytes);
    _bufferOffset += bytes;
  }

  /// Skips [bytes] without loading them and discards the buffer
  Future<void> seek(int bytes) {
    _fileOffset = offset + bytes;
    _bufferOffset = 0;
    _bufferSize = 0;
    return file.setPosition(_fileOffset);
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Uint8List viewBytes(int bytes) {
    assert(bytes >= 0 && remainingInBuffer >= bytes);
    final view = Uint8List.view(buffer.buffer, _bufferOffset, bytes);
    _bufferOffset += bytes;
    return view;
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Uint8List peekBytes(int bytes) {
    assert(bytes >= 0 && remainingInBuffer >= bytes);
    return Uint8List.view(buffer.buffer, _bufferOffset, bytes);
  }

  /// Not part of public API
  Future<int> loadBytes(int bytes) async {
    assert(bytes > 0);
    final remaining = remainingInBuffer;
    if (remaining >= bytes) {
      return remaining;
    } else {
      final oldBuffer = buffer;
      if (buffer.length < bytes) {
        buffer = Uint8List(bytes);
      }

      buffer.setRange(0, remaining, oldBuffer, _bufferOffset);

      _bufferOffset = 0;
      final readBytes =
          await file.readInto(buffer, remaining, max(bytes, _chunkSize));
      _bufferSize = remaining + readBytes;
      _fileOffset += readBytes;

      return _bufferSize;
    }
  }
}
