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

  var _bufferSize = 0;
  var _bufferOffset = 0;
  var _fileOffset = 0;

  /// Not part of public API
  int get remainingInBuffer => _bufferSize - _bufferOffset;

  /// Not part of public API
  int get offset => _fileOffset - remainingInBuffer;

  /// Not part of public API
  BufferedFileReader(this.file, [int bufferSize = defaultChunkSize])
      : buffer = Uint8List(bufferSize);

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void skip(int bytes) {
    assert(bytes >= 0 && remainingInBuffer >= bytes);
    _bufferOffset += bytes;
  }

  /// Not part of public API
  ///
  /// Moves forward [bytes] from the current offset.
  ///
  /// Bytes already buffered are discarded. Anything past the buffer is skipped
  /// in the file without reading it.
  Future<void> skipAhead(int bytes) async {
    assert(bytes >= 0);
    final remaining = remainingInBuffer;
    if (bytes <= remaining) {
      _bufferOffset += bytes;
      return;
    }

    final position = _fileOffset + (bytes - remaining);
    _bufferSize = 0;
    _bufferOffset = 0;
    await file.setPosition(position);
    _fileOffset = position;
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
  ///
  /// Reads until at least [bytes] are available.
  ///
  /// When [maxRead] is set, at most that many new bytes are read. This keeps a
  /// large frame from being pulled into memory just to inspect its header.
  Future<int> loadBytes(int bytes, {int? maxRead}) async {
    assert(bytes > 0);
    assert(maxRead == null || maxRead > 0);
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
      final capacity = buffer.length - remaining;
      final toRead = maxRead == null ? capacity : min(capacity, maxRead);
      final readBytes = await file.readInto(
        buffer,
        remaining,
        remaining + toRead,
      );
      _bufferSize = remaining + readBytes;
      _fileOffset += readBytes;

      return _bufferSize;
    }
  }
}
