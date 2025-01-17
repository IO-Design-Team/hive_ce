import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/crypto/crc32.dart';
import 'package:hive_ce/src/object/hive_list_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:meta/meta.dart';

/// Not part of public API
class BinaryWriterImpl extends BinaryWriter {
  static const _initBufferSize = 4096;

  final TypeRegistryImpl _typeRegistry;
  Uint8List _buffer = Uint8List(_initBufferSize);

  ByteData? _byteDataInstance;

  int _offset = 0;

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  ByteData get _byteData {
    _byteDataInstance ??= ByteData.view(_buffer.buffer);
    return _byteDataInstance!;
  }

  /// Not part of public API
  BinaryWriterImpl(TypeRegistry typeRegistry)
      : _typeRegistry = typeRegistry as TypeRegistryImpl;

  /// Not part of public API
  @visibleForTesting
  BinaryWriterImpl.withBuffer(this._buffer, this._typeRegistry);

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
    final bytes = encoder.convert(value);
    if (writeByteCount) {
      writeUint32(bytes.length);
    }
    _addBytes(bytes);
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
      final strBytes = encoder.convert(str);
      writeUint32(strBytes.length);
      _addBytes(strBytes);
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
    for (final key in map.keys) {
      write(key);
      write(map[key]);
    }
  }

  /// Not part of public API
  void writeKey(dynamic key) {
    ArgumentError.checkNotNull(key);

    if (key is String) {
      writeByte(FrameKeyType.utf8StringT);
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
  @visibleForTesting
  void writeTypeId(int typeId) {
    if (typeId < 256) {
      writeByte(typeId);
    } else {
      writeByte(FrameValueType.typeIdExtension);
      writeByte(typeId);
      writeByte(typeId >> 8);
    }
  }

  /// Not part of public API
  int writeFrame(Frame frame, {HiveCipher? cipher}) {
    final startOffset = _offset;
    _reserveBytes(4);
    _offset += 4; // reserve bytes for length

    writeKey(frame.key);

    if (!frame.deleted) {
      if (cipher == null) {
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
      crc: cipher?.calculateKeyCrc() ?? 0,
    );
    writeUint32(crc);

    return frameLength;
  }

  @override
  void write<T>(T value, {bool withTypeId = true}) {
    final int typeId;
    final void Function() write;
    if (value == null) {
      typeId = FrameValueType.nullT;
      write = () {};
    } else if (value is int) {
      typeId = FrameValueType.intT;
      write = () => writeInt(value);
    } else if (value is double) {
      typeId = FrameValueType.doubleT;
      write = () => writeDouble(value);
    } else if (value is bool) {
      typeId = FrameValueType.boolT;
      write = () => writeBool(value);
    } else if (value is String) {
      typeId = FrameValueType.stringT;
      write = () => writeString(value);
    } else if (value is List || value is Set) {
      _writeList(value as Iterable, withTypeId: withTypeId);
      return;
    } else if (value is Map) {
      typeId = FrameValueType.mapT;
      write = () => writeMap(value);
    } else {
      final resolved = _typeRegistry.findAdapterForValue(value);
      if (resolved == null) {
        throw HiveError('Cannot write, unknown type: ${value.runtimeType}. '
            'Did you forget to register an adapter?');
      }
      typeId = resolved.typeId;
      write = () => resolved.adapter.write(this, value);
    }

    if (withTypeId) writeTypeId(typeId);
    write();
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _writeList(Iterable value, {bool withTypeId = true}) {
    final int typeId;
    final void Function() write;
    if (value is HiveList) {
      typeId = FrameValueType.hiveListT;
      write = () => writeHiveList(value);
    } else if (value is Uint8List) {
      typeId = FrameValueType.byteListT;
      write = () => writeByteList(value);
    } else if (value is List<int>) {
      typeId = FrameValueType.intListT;
      write = () => writeIntList(value);
    } else if (value is List<double>) {
      typeId = FrameValueType.doubleListT;
      write = () => writeDoubleList(value);
    } else if (value is List<bool>) {
      typeId = FrameValueType.boolListT;
      write = () => writeBoolList(value);
    } else if (value is List<String>) {
      typeId = FrameValueType.stringListT;
      write = () => writeStringList(value);
    } else if (value is List) {
      typeId = FrameValueType.listT;
      write = () => writeList(value);
    } else if (value is Set<int>) {
      typeId = FrameValueType.intSetT;
      write = () => writeIntList(value.toList());
    } else if (value is Set<double>) {
      typeId = FrameValueType.doubleSetT;
      write = () => writeDoubleList(value.toList());
    } else if (value is Set<String>) {
      typeId = FrameValueType.stringSetT;
      write = () => writeStringList(value.toList());
    } else if (value is Set) {
      typeId = FrameValueType.setT;
      write = () => writeList(value.toList());
    } else {
      throw HiveError('Cannot write, unknown type: ${value.runtimeType}.');
    }

    if (withTypeId) writeTypeId(typeId);
    write();
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void writeEncrypted(
    dynamic value,
    HiveCipher cipher, {
    bool withTypeId = true,
  }) {
    final valueWriter = BinaryWriterImpl(_typeRegistry)
      ..write(value, withTypeId: withTypeId);
    final inp = valueWriter._buffer;
    final inpLength = valueWriter._offset;

    _reserveBytes(cipher.maxEncryptedSize(inp));

    final len = cipher.encrypt(inp, 0, inpLength, _buffer, _offset);

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
