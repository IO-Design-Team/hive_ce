import 'dart:io';
import 'dart:typed_data';

/// Not part of public API
class BufferedFileWriter {
  static const _defaultMaxBufferSize = 64000;

  final RandomAccessFile _file;

  final Uint8List _buffer;

  var _offset = 0;

  /// Not part of public API
  BufferedFileWriter(this._file, [int maxBufferSize = _defaultMaxBufferSize])
      : _buffer = Uint8List(maxBufferSize);

  /// Not part of public API
  Future<void> write(List<int> bytes) async {
    final length = bytes.length;
    if (length == 0) return;

    if (_offset + length > _buffer.length) {
      await flush();
    }

    if (length >= _buffer.length) {
      await _file.writeFrom(bytes);
      return;
    }

    _buffer.setRange(_offset, _offset + length, bytes);
    _offset += length;

    if (_offset == _buffer.length) {
      await flush();
    }
  }

  /// Not part of public API
  Future<void> flush() {
    if (_offset == 0) return Future.value();
    final length = _offset;
    _offset = 0;
    return _file.writeFrom(Uint8List.sublistView(_buffer, 0, length));
  }
}
