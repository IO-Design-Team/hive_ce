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
class BinaryReaderImpl extends BinaryReader {
  final Uint8List _buffer;
  final ByteData _byteData;
  final int _bufferLength;
  final TypeRegistryImpl _typeRegistry;

  int _bufferLimit;
  int _offset = 0;

  /// Not part of public API
  BinaryReaderImpl(this._buffer, TypeRegistry typeRegistry, [int? bufferLength])
      : _byteData = ByteData.view(_buffer.buffer, _buffer.offsetInBytes),
        _bufferLength = bufferLength ?? _buffer.length,
        _bufferLimit = bufferLength ?? _buffer.length,
        _typeRegistry = typeRegistry as TypeRegistryImpl;

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @override
  int get availableBytes => _bufferLimit - _offset;

  @override
  int get usedBytes => _offset;

  void _limitAvailableBytes(int bytes) {
    _requireBytes(bytes);
    _bufferLimit = _offset + bytes;
  }

  void _resetLimit() {
    _bufferLimit = _bufferLength;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _requireBytes(int bytes) {
    if (_offset + bytes > _bufferLimit) {
      throw RangeError('Not enough bytes available.');
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @override
  void skip(int bytes) {
    _requireBytes(bytes);
    _offset += bytes;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @override
  int readByte() {
    _requireBytes(1);
    return _buffer[_offset++];
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @override
  Uint8List viewBytes(int bytes) {
    _requireBytes(bytes);
    _offset += bytes;
    return _buffer.view(_offset - bytes, bytes);
  }

  @override
  Uint8List peekBytes(int bytes) {
    _requireBytes(bytes);
    return _buffer.view(_offset, bytes);
  }

  @override
  int readWord() {
    _requireBytes(2);
    return _buffer[_offset++] | _buffer[_offset++] << 8;
  }

  @override
  int readInt32() {
    _requireBytes(4);
    _offset += 4;
    return _byteData.getInt32(_offset - 4, Endian.little);
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @override
  int readUint32() {
    _requireBytes(4);
    _offset += 4;
    return _buffer.readUint32(_offset - 4);
  }

  /// Not part of public API
  int peekUint32() {
    _requireBytes(4);
    return _buffer.readUint32(_offset);
  }

  @override
  int readInt() {
    return readDouble().toInt();
  }

  @override
  double readDouble() {
    _requireBytes(8);
    final value = _byteData.getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  @override
  bool readBool() {
    return readByte() > 0;
  }

  @override
  String readString([
    int? byteCount,
    Converter<List<int>, String> decoder = BinaryReader.utf8Decoder,
  ]) {
    byteCount ??= readUint32();
    final view = viewBytes(byteCount);
    return decoder.convert(view);
  }

  @override
  Uint8List readByteList([int? length]) {
    length ??= readUint32();
    _requireBytes(length);
    final byteList = _buffer.sublist(_offset, _offset + length);
    _offset += length;
    return byteList;
  }

  @override
  List<int> readIntList([int? length]) {
    length ??= readUint32();
    _requireBytes(length * 8);
    final byteData = _byteData;
    final list = List<int>.filled(length, 0, growable: true);
    for (var i = 0; i < length; i++) {
      list[i] = byteData.getFloat64(_offset, Endian.little).toInt();
      _offset += 8;
    }
    return list;
  }

  @override
  List<double> readDoubleList([int? length]) {
    length ??= readUint32();
    _requireBytes(length * 8);
    final byteData = _byteData;
    final list = List<double>.filled(length, 0.0, growable: true);
    for (var i = 0; i < length; i++) {
      list[i] = byteData.getFloat64(_offset, Endian.little);
      _offset += 8;
    }
    return list;
  }

  @override
  List<bool> readBoolList([int? length]) {
    length ??= readUint32();
    _requireBytes(length);
    final list = List<bool>.filled(length, false, growable: true);
    for (var i = 0; i < length; i++) {
      list[i] = _buffer[_offset++] > 0;
    }
    return list;
  }

  @override
  List<String> readStringList([
    int? length,
    Converter<List<int>, String> decoder = BinaryReader.utf8Decoder,
  ]) {
    length ??= readUint32();
    final list = List<String>.filled(length, '', growable: true);
    for (var i = 0; i < length; i++) {
      list[i] = readString(null, decoder);
    }
    return list;
  }

  @override
  List readList([int? length]) {
    length ??= readUint32();
    final list = List<dynamic>.filled(length, null, growable: true);
    for (var i = 0; i < length; i++) {
      list[i] = read();
    }
    return list;
  }

  @override
  Map readMap([int? length]) {
    length ??= readUint32();
    final map = <dynamic, dynamic>{};
    for (var i = 0; i < length; i++) {
      map[read()] = read();
    }
    return map;
  }

  /// Not part of public API
  dynamic readKey() {
    final keyType = readByte();
    if (keyType == FrameKeyType.uintT) {
      return readUint32();
    } else if (keyType == FrameKeyType.utf8StringT) {
      final byteCount = readByte();
      return BinaryReader.utf8Decoder.convert(viewBytes(byteCount));
    } else {
      throw HiveError('Unsupported key type. Frame might be corrupted.');
    }
  }

  @override
  HiveList readHiveList([int? length]) {
    length ??= readUint32();
    final boxNameLength = readByte();
    final boxName = String.fromCharCodes(viewBytes(boxNameLength));
    final keys = List<dynamic>.filled(length, null, growable: true);
    for (var i = 0; i < length; i++) {
      keys[i] = readKey();
    }

    return HiveListImpl.lazy(boxName, keys);
  }

  /// Read a type ID and handle extension
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @visibleForTesting
  int readTypeId() {
    final typeId = readByte();
    if (typeId == FrameValueType.typeIdExtension) {
      return readWord();
    } else {
      return typeId;
    }
  }

  /// Not part of public API
  Frame? readFrame({
    HiveCipher? cipher,
    bool lazy = false,
    int frameOffset = 0,
    bool verbatim = false,
  }) {
    // frame length is stored on 4 bytes
    if (availableBytes < 4) return null;

    // frame length should be at least 8 bytes
    final frameLength = readUint32();
    if (frameLength < 8) return null;

    // frame is bigger than avaible bytes
    if (availableBytes < frameLength - 4) return null;

    final crc = _buffer.readUint32(_offset + frameLength - 8);
    final computedCrc = Crc32.compute(
      _buffer,
      offset: _offset - 4,
      length: frameLength - 4,
      crc: cipher?.calculateKeyCrc() ?? 0,
    );

    // frame is corrupted or provided chiper is different
    if (computedCrc != crc) return null;

    _limitAvailableBytes(frameLength - 8);
    Frame frame;
    final dynamic key = readKey();

    if (availableBytes == 0) {
      frame = Frame.deleted(key);
    } else if (lazy) {
      frame = Frame.lazy(key, verbatim: verbatim);
    } else if (verbatim) {
      frame = Frame(key, viewBytes(availableBytes), verbatim: verbatim);
    } else if (cipher == null) {
      frame = Frame(key, read());
    } else {
      frame = Frame(key, readEncrypted(cipher));
    }

    frame
      ..length = frameLength
      ..offset = frameOffset;

    skip(availableBytes);
    _resetLimit();
    skip(4); // Skip CRC

    return frame;
  }

  @override
  dynamic read([int? typeId]) {
    typeId ??= readTypeId();
    switch (typeId) {
      case FrameValueType.nullT:
        return null;
      case FrameValueType.intT:
        return readInt();
      case FrameValueType.doubleT:
        return readDouble();
      case FrameValueType.boolT:
        return readBool();
      case FrameValueType.stringT:
        return readString();
      case FrameValueType.byteListT:
        return readByteList();
      case FrameValueType.intListT:
        return readIntList();
      case FrameValueType.doubleListT:
        return readDoubleList();
      case FrameValueType.boolListT:
        return readBoolList();
      case FrameValueType.stringListT:
        return readStringList();
      case FrameValueType.listT:
        return readList();
      case FrameValueType.mapT:
        return readMap();
      case FrameValueType.hiveListT:
        return readHiveList();
      case FrameValueType.intSetT:
        return readIntList().toSet();
      case FrameValueType.doubleSetT:
        return readDoubleList().toSet();
      case FrameValueType.stringSetT:
        return readStringList().toSet();
      case FrameValueType.setT:
        return readList().toSet();
      default:
        final resolved = _typeRegistry.findAdapterForTypeId(typeId);
        if (resolved == null) {
          throw HiveError('Cannot read, unknown typeId: $typeId. '
              'Did you forget to register an adapter?');
        }
        return resolved.adapter.read(this);
    }
  }

  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  dynamic readEncrypted(HiveCipher cipher) {
    final inpLength = availableBytes;
    final out = Uint8List(inpLength);
    final outLength = cipher.decrypt(_buffer, _offset, inpLength, out, 0);
    _offset += inpLength;

    final valueReader = BinaryReaderImpl(out, _typeRegistry, outLength);
    return valueReader.read();
  }
}
