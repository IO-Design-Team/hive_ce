import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/crypto/crc32.dart';
import 'package:hive_ce/src/object/hive_list_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:hive_ce/src/util/logger.dart';
import 'package:meta/meta.dart';

/// Not part of public API
class BinaryWriterImpl extends BinaryWriter {
  static const _initBufferSize = 4096;

  /// The maximum integer that can be stored in a 64 bit float (2^53)
  static const maxInt = 9007199254740992;

  /// The type registry to use for writing values
  final TypeRegistryImpl typeRegistry;
  var _buffer = Uint8List(_initBufferSize);

  ByteData? _byteDataInstance;

  var _offset = 0;

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  ByteData get _byteData => _byteDataInstance ??= ByteData.view(_buffer.buffer);

  /// Not part of public API
  BinaryWriterImpl(TypeRegistry typeRegistry)
      : typeRegistry = typeRegistry as TypeRegistryImpl;

  /// Not part of public API
  @visibleForTesting
  BinaryWriterImpl.withBuffer(this._buffer, this.typeRegistry);

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _reserveBytes(int count) {
    if (_buffer.length - _offset < count) {
      _increaseBufferSize(count);
    }
  }

  void _increaseBufferSize(int count) {
// We will create a list in the range of 2-4 times larger than required.
    final newSize = _pow2roundup((_offset + count) * 2);
    final newBuffer = Uint8List(newSize);
    newBuffer.setRange(0, _offset, _buffer);
    _buffer = newBuffer;
    _byteDataInstance = null;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _addBytes(List<int> bytes) {
    final length = bytes.length;
    _reserveBytes(length);
    _buffer.setRange(_offset, _offset + length, bytes);
    _offset += length;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @override
  void writeByte(int byte) {
    _reserveBytes(1);
    _buffer[_offset++] = byte;
  }

  @override
  void writeWord(int value) {
    _reserveBytes(2);
    _buffer[_offset++] = value;
    _buffer[_offset++] = value >> 8;
  }

  @override
  void writeInt32(int value) {
    _reserveBytes(4);
    _byteData.setInt32(_offset, value, Endian.little);
    _offset += 4;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @override
  void writeUint32(int value) {
    _reserveBytes(4);
    _buffer.writeUint32(_offset, value);
    _offset += 4;
  }

  @override
  void writeInt(int value) {
    // Web truncates values greater than 2^53 to 2^53
    if (Logger.bigIntWarning && value >= maxInt) {
      Logger.w(HiveWarning.bigInt);
    }
    writeDouble(value.toDouble());
  }

  @override
  void writeDouble(double value) {
    _reserveBytes(8);
    _byteData.setFloat64(_offset, value, Endian.little);
    _offset += 8;
  }

  @override
  void writeBool(bool value) {
    writeByte(value ? 1 : 0);
  }

  @override
  void writeString(
    String value, {
    bool writeByteCount = true,
    Converter<String, List<int>> encoder = BinaryWriter.utf8Encoder,
  }) {
    if (identical(encoder, BinaryWriter.utf8Encoder)) {
      final length = value.length;
      final countBytes = writeByteCount ? 4 : 0;
      _reserveBytes(countBytes + length);
      if (_writeAscii(value, _offset + countBytes)) {
        if (writeByteCount) _buffer.writeUint32(_offset, length);
        _offset += countBytes + length;
        return;
      }
    }

    final bytes = encoder.convert(value);
    if (writeByteCount) {
      writeUint32(bytes.length);
    }
    _addBytes(bytes);
  }

  /// Copies [value] to [offset] if it is ASCII, which is the same as UTF-8
  ///
  /// The buffer must have room for `value.length` bytes at [offset]
  bool _writeAscii(String value, int offset) {
    final buffer = _buffer;
    for (var i = 0; i < value.length; i++) {
      final codeUnit = value.codeUnitAt(i);
      if (codeUnit > 0x7f) return false;
      buffer[offset + i] = codeUnit;
    }
    return true;
  }

  @override
  void writeByteList(List<int> bytes, {bool writeLength = true}) {
    if (writeLength) {
      writeUint32(bytes.length);
    }
    _addBytes(bytes);
  }

  @override
  void writeIntList(List<int> list, {bool writeLength = true}) {
    final length = list.length;
    if (writeLength) {
      writeUint32(length);
    }
    _reserveBytes(length * 8);
    final byteData = _byteData;
    for (var i = 0; i < length; i++) {
      byteData.setFloat64(_offset, list[i].toDouble(), Endian.little);
      _offset += 8;
    }
  }

  @override
  void writeDoubleList(List<double> list, {bool writeLength = true}) {
    final length = list.length;
    if (writeLength) {
      writeUint32(length);
    }
    _reserveBytes(length * 8);
    final byteData = _byteData;
    for (var i = 0; i < length; i++) {
      byteData.setFloat64(_offset, list[i], Endian.little);
      _offset += 8;
    }
  }

  @override
  void writeBoolList(List<bool> list, {bool writeLength = true}) {
    final length = list.length;
    if (writeLength) {
      writeUint32(length);
    }
    _reserveBytes(length);
    for (var i = 0; i < length; i++) {
      _buffer[_offset++] = list[i] ? 1 : 0;
    }
  }

  @override
  void writeStringList(
    List<String> list, {
    bool writeLength = true,
    Converter<String, List<int>> encoder = BinaryWriter.utf8Encoder,
  }) {
    if (writeLength) {
      writeUint32(list.length);
    }
    for (final str in list) {
      writeString(str, encoder: encoder);
    }
  }

  @override
  void writeList(List list, {bool writeLength = true}) {
    if (writeLength) {
      writeUint32(list.length);
    }
    for (var i = 0; i < list.length; i++) {
      write(list[i]);
    }
  }

  @override
  void writeMap(Map<dynamic, dynamic> map, {bool writeLength = true}) {
    if (writeLength) {
      writeUint32(map.length);
    }
    map.forEach((key, value) {
      write(key);
      write(value);
    });
  }

  /// Not part of public API
  void writeKey(dynamic key) {
    ArgumentError.checkNotNull(key);

    if (key is String) {
      writeByte(FrameKeyType.utf8StringT);
      final length = key.length;
      _reserveBytes(1 + length);
      if (_writeAscii(key, _offset + 1)) {
        _buffer[_offset] = length;
        _offset += 1 + length;
        return;
      }

      final bytes = BinaryWriter.utf8Encoder.convert(key);
      writeByte(bytes.length);
      _addBytes(bytes);
    } else {
      writeByte(FrameKeyType.uintT);
      writeUint32(key as int);
    }
  }

  @override
  void writeHiveList(HiveList list, {bool writeLength = true}) {
    if (writeLength) {
      writeUint32(list.length);
    }
    final boxName = (list as HiveListImpl).boxName;
    writeByte(boxName.length);
    _addBytes(boxName.codeUnits);
    for (final obj in list) {
      writeKey(obj.key);
    }
  }

  /// Handle type ID writing
  /// - Type IDs less than 256 are written as a single byte
  /// - Type IDs greater than 255 are written as [FrameValueType.typeIdExtension]
  ///   followed by two bytes
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void writeTypeId(int typeId) {
    if (typeId < 256) {
      writeByte(typeId);
    } else {
      writeByte(FrameValueType.typeIdExtension);
      writeWord(typeId);
    }
  }

  /// Not part of public API
  int writeFrame(
    Frame frame, {
    HiveCipher? cipher,
    int? keyCrc,
    bool verbatim = false,
  }) {
    final startOffset = _offset;
    _reserveBytes(4);
    _offset += 4; // reserve bytes for length

    writeKey(frame.key);

    if (!frame.deleted) {
      if (verbatim) {
        writeBytes(frame.value as Uint8List);
      } else if (cipher == null) {
        write(frame.value);
      } else {
        writeEncrypted(frame.value, cipher);
      }
    }

    final frameLength = _offset - startOffset + 4;
    _buffer.writeUint32(startOffset, frameLength);

    final crc = Crc32.compute(
      _buffer,
      offset: startOffset,
      length: frameLength - 4,
      crc: keyCrc ?? cipher?.calculateKeyCrc() ?? 0,
    );
    writeUint32(crc);

    return frameLength;
  }

  /// Add the given bytes to the buffer verbatim
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  int writeBytes(Uint8List bytes) {
    final length = bytes.length;
    _reserveBytes(length);
    _buffer.setRange(_offset, _offset + length, bytes);
    _offset += length;
    return length;
  }

  @override
  void write<T>(T value, {bool withTypeId = true}) {
    if (value == null) {
      if (withTypeId) writeTypeId(FrameValueType.nullT);
    } else if (value is int) {
      if (withTypeId) writeTypeId(FrameValueType.intT);
      writeInt(value);
    } else if (value is double) {
      if (withTypeId) writeTypeId(FrameValueType.doubleT);
      writeDouble(value);
    } else if (value is bool) {
      if (withTypeId) writeTypeId(FrameValueType.boolT);
      writeBool(value);
    } else if (value is String) {
      if (withTypeId) writeTypeId(FrameValueType.stringT);
      writeString(value);
    } else if (value is List || value is Set) {
      _writeList(value as Iterable, withTypeId: withTypeId);
    } else if (value is Map) {
      if (withTypeId) writeTypeId(FrameValueType.mapT);
      writeMap(value);
    } else {
      final resolved = typeRegistry.findAdapterForValue(value);
      if (resolved == null) {
        throw HiveError('Cannot write, unknown type: ${value.runtimeType}. '
            'Did you forget to register an adapter?');
      }
      if (withTypeId) writeTypeId(resolved.typeId);
      resolved.adapter.write(this, value);
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _writeList(Iterable value, {bool withTypeId = true}) {
    if (value is HiveList) {
      if (withTypeId) writeTypeId(FrameValueType.hiveListT);
      writeHiveList(value);
    } else if (value is Uint8List) {
      if (withTypeId) writeTypeId(FrameValueType.byteListT);
      writeByteList(value);
    } else if (value is List<int>) {
      if (withTypeId) writeTypeId(FrameValueType.intListT);
      writeIntList(value);
    } else if (value is List<double>) {
      if (withTypeId) writeTypeId(FrameValueType.doubleListT);
      writeDoubleList(value);
    } else if (value is List<bool>) {
      if (withTypeId) writeTypeId(FrameValueType.boolListT);
      writeBoolList(value);
    } else if (value is List<String>) {
      if (withTypeId) writeTypeId(FrameValueType.stringListT);
      writeStringList(value);
    } else if (value is List) {
      if (withTypeId) writeTypeId(FrameValueType.listT);
      writeList(value);
    } else if (value is Set<int>) {
      if (withTypeId) writeTypeId(FrameValueType.intSetT);
      writeIntList(value.toList());
    } else if (value is Set<double>) {
      if (withTypeId) writeTypeId(FrameValueType.doubleSetT);
      writeDoubleList(value.toList());
    } else if (value is Set<String>) {
      if (withTypeId) writeTypeId(FrameValueType.stringSetT);
      writeStringList(value.toList());
    } else if (value is Set) {
      if (withTypeId) writeTypeId(FrameValueType.setT);
      writeList(value.toList());
    } else {
      throw HiveError('Cannot write, unknown type: ${value.runtimeType}.');
    }
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void writeEncrypted(
    dynamic value,
    HiveCipher cipher, {
    bool withTypeId = true,
  }) {
    final valueWriter = BinaryWriterImpl(typeRegistry)
      ..write(value, withTypeId: withTypeId);
    final inp = valueWriter.toBytes();

    _reserveBytes(cipher.maxEncryptedSize(inp));

    final len = cipher.encrypt(inp, 0, inp.length, _buffer, _offset);

    _offset += len;
  }

  /// Not part of public API
  Uint8List toBytes() {
    return Uint8List.view(_buffer.buffer, 0, _offset);
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  static int _pow2roundup(int x) {
    assert(x > 0);
    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    return x + 1;
  }
}
