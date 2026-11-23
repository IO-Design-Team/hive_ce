import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/object/hive_object.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../util/print_utils.dart';
import '../frames.dart';
import '../mocks.dart';

List<int> bytes(ByteData byteData) => byteData.buffer.asUint8List();

BinaryWriterImpl getWriter() => BinaryWriterImpl(TypeRegistryImpl());

BinaryReaderImpl fromBytes(List<int> bytes) {
  return BinaryReaderImpl(Uint8List.fromList(bytes), TypeRegistryImpl());
}

@immutable
class _SpyCipher implements HiveCipher {
  final HiveCipher _delegate;
  final inputBufferLengths = <int>[];

  _SpyCipher(this._delegate);

  @override
  int calculateKeyCrc() => _delegate.calculateKeyCrc();

  @override
  int maxEncryptedSize(Uint8List inp) => _delegate.maxEncryptedSize(inp);

  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    inputBufferLengths.add(inp.buffer.lengthInBytes);
    return _delegate.encrypt(inp, inpOff, inpLength, out, outOff);
  }

  @override
  int decrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) =>
      _delegate.decrypt(inp, inpOff, inpLength, out, outOff);
}

@immutable
class _TrackedValue {
  final dynamic payload;
  final void Function(BinaryWriter writer)? onWrite;

  const _TrackedValue(this.payload, {this.onWrite});
}

class _TrackingAdapter extends TypeAdapter<_TrackedValue> {
  @override
  final int typeId;
  final writers = <BinaryWriter>[];

  _TrackingAdapter([this.typeId = 100]);

  @override
  _TrackedValue read(BinaryReader reader) {
    return _TrackedValue(reader.read());
  }

  @override
  void write(BinaryWriter writer, _TrackedValue obj) {
    writers.add(writer);
    final onWrite = obj.onWrite;
    if (onWrite != null) {
      onWrite(writer);
    } else {
      writer.write(obj.payload);
    }
  }
}

dynamic _decryptValue(
  Uint8List encrypted,
  HiveCipher cipher,
  TypeRegistry registry, {
  int? typeId,
}) {
  final out = Uint8List(encrypted.length);
  final len = cipher.decrypt(encrypted, 0, encrypted.length, out, 0);
  final reader = BinaryReaderImpl(out.sublist(0, len), registry);
  return reader.read(typeId);
}

void main() {
  group('BinaryWriter', () {
    test('.writeByte()', () {
      var bw = getWriter();
      bw.writeByte(0);
      expect(bw.toBytes(), [0]);

      bw = getWriter();
      bw.writeByte(17);
      expect(bw.toBytes(), [17]);

      bw = getWriter();
      bw.writeByte(255);
      expect(bw.toBytes(), [255]);

      bw = getWriter();
      bw.writeByte(257);
      expect(bw.toBytes(), [1]);
    });

    test('.writeWord()', () {
      var bw = getWriter();
      bw.writeWord(0);
      expect(bw.toBytes(), [0, 0]);

      bw = getWriter();
      bw.writeWord(256);
      expect(bw.toBytes(), [0, 1]);

      bw = getWriter();
      bw.writeWord(65535);
      expect(bw.toBytes(), [255, 255]);

      bw = getWriter();
      bw.writeWord(65536);
      expect(bw.toBytes(), [0, 0]);
    });

    test('.writeInt32()', () {
      final bd = ByteData(4);

      var bw = getWriter();
      bw.writeInt32(0);
      bd.setInt32(0, 0, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt32(1);
      bd.setInt32(0, 1, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt32(-1);
      bd.setInt32(0, -1, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt32(65535);
      bd.setInt32(0, 65535, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt32(65536);
      bd.setInt32(0, 65536, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt32(-65536);
      bd.setInt32(0, -65536, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt32(-65537);
      bd.setInt32(0, -65537, Endian.little);
      expect(bw.toBytes(), bytes(bd));
    });

    test('.writeUint32()', () {
      final bd = ByteData(4);

      var bw = getWriter();
      bw.writeUint32(0);
      bd.setUint32(0, 0, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeUint32(1);
      bd.setUint32(0, 1, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeUint32(2147483647);
      bd.setUint32(0, 2147483647, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeUint32(-2147483648);
      bd.setUint32(0, -2147483648, Endian.little);
      expect(bw.toBytes(), bytes(bd));
    });

    test('.writeInt()', () async {
      final bd = ByteData(8);

      var bw = getWriter();
      bw.writeInt(0);
      bd.setFloat64(0, 0, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt(1);
      bd.setFloat64(0, 1, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt(-1);
      bd.setFloat64(0, -1, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt(BinaryWriterImpl.maxInt);
      bd.setFloat64(0, BinaryWriterImpl.maxInt.toDouble(), Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeInt(-BinaryWriterImpl.maxInt);
      bd.setFloat64(0, -BinaryWriterImpl.maxInt.toDouble(), Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      final output1 =
          await captureOutput(() => bw.writeInt(BinaryWriterImpl.maxInt - 1))
              .toList();
      expect(output1, isEmpty);

      bw = getWriter();
      final output2 =
          await captureOutput(() => bw.writeInt(BinaryWriterImpl.maxInt))
              .toList();
      expect(output2, contains(HiveWarning.bigInt));

      bw = getWriter();
      bw.writeInt(BinaryWriterImpl.maxInt + 1);
      final br = fromBytes(bw.toBytes());
      // Precision loss
      expect(br.readInt(), BinaryWriterImpl.maxInt);
    });

    test('.writeDouble()', () {
      final bd = ByteData(8);

      var bw = getWriter();
      bw.writeDouble(0);
      bd.setFloat64(0, 0, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeDouble(16.399483);
      bd.setFloat64(0, 16.399483, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeDouble(double.nan);
      bd.setFloat64(0, double.nan, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeDouble(double.infinity);
      bd.setFloat64(0, double.infinity, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeDouble(double.negativeInfinity);
      bd.setFloat64(0, double.negativeInfinity, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeDouble(double.maxFinite);
      bd.setFloat64(0, double.maxFinite, Endian.little);
      expect(bw.toBytes(), bytes(bd));

      bw = getWriter();
      bw.writeDouble(double.minPositive);
      bd.setFloat64(0, double.minPositive, Endian.little);
      expect(bw.toBytes(), bytes(bd));
    });

    test('.writeBool()', () {
      var bw = getWriter();
      bw.writeBool(true);
      expect(bw.toBytes(), [1]);

      bw = getWriter();
      bw.writeBool(false);
      expect(bw.toBytes(), [0]);
    });

    test('.writeString()', () {
      var bw = getWriter();
      bw.writeString('');
      expect(bw.toBytes(), [0, 0, 0, 0]);

      bw = getWriter();
      bw.writeString('', writeByteCount: false);
      expect(bw.toBytes(), []);

      bw = getWriter();
      bw.writeString('𠁠🇬🇵');
      expect(bw.toBytes(), [
        12, 0, 0, 0, 0xf0, 0xa0, 0x81, 0xa0, 0xf0, //
        0x9f, 0x87, 0xac, 0xf0, 0x9f, 0x87, 0xb5, //
      ]);

      bw = getWriter();
      bw.writeString('👨‍👨‍👧‍👦', writeByteCount: false);
      expect(bw.toBytes(), [
        0xf0, 0x9f, 0x91, 0xa8, 0xe2, 0x80, 0x8d, 0xf0, 0x9f, 0x91, 0xa8, //
        0xe2, 0x80, 0x8d, 0xf0, 0x9f, 0x91, 0xa7, 0xe2, 0x80, 0x8d, 0xf0, //
        0x9f, 0x91, 0xa6, //
      ]);
    });

    test('.writeByteList()', () {
      var bw = getWriter();
      bw.writeByteList([]);
      expect(bw.toBytes(), [0, 0, 0, 0]);

      bw = getWriter();
      bw.writeByteList([], writeLength: false);
      expect(bw.toBytes(), []);

      bw = getWriter();
      bw.writeByteList([1, 2, 3, 4]);
      expect(bw.toBytes(), [4, 0, 0, 0, 1, 2, 3, 4]);

      bw = getWriter();
      bw.writeByteList([1, 2, 3, 4], writeLength: false);
      expect(bw.toBytes(), [1, 2, 3, 4]);
    });

    test('.writeIntList()', () {
      var bw = getWriter();
      bw.writeIntList([]);
      expect(bw.toBytes(), [0, 0, 0, 0]);

      bw = getWriter();
      bw.writeIntList([], writeLength: false);
      expect(bw.toBytes(), []);

      bw = getWriter();
      bw.writeIntList([1, 2]);
      expect(
        bw.toBytes(),
        [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 240, 63, 0, 0, 0, 0, 0, 0, 0, 64],
      );

      bw = getWriter();
      bw.writeIntList([1, 2], writeLength: false);
      expect(
        bw.toBytes(),
        [0, 0, 0, 0, 0, 0, 240, 63, 0, 0, 0, 0, 0, 0, 0, 64],
      );

      bw = getWriter()
        ..writeByte(0xAA)
        ..writeIntList([10, -20])
        ..writeByte(0xBB);
      var br = fromBytes(bw.toBytes());
      expect(br.readByte(), 0xAA);
      expect(br.readIntList(), [10, -20]);
      expect(br.readByte(), 0xBB);

      bw = getWriter()
        ..writeByte(0xAA)
        ..writeIntList([10, -20], writeLength: false)
        ..writeByte(0xBB);
      br = fromBytes(bw.toBytes());
      expect(br.readByte(), 0xAA);
      expect(br.readIntList(2), [10, -20]);
      expect(br.readByte(), 0xBB);

      final largeInts = List.generate(1000, (i) => i - 500);
      bw = getWriter()..writeIntList(largeInts);
      expect(fromBytes(bw.toBytes()).readIntList(), largeInts);
    });

    test('.writeDoubleList()', () {
      var bw = getWriter();
      bw.writeDoubleList([]);
      expect(bw.toBytes(), [0, 0, 0, 0]);

      bw = getWriter();
      bw.writeDoubleList([], writeLength: false);
      expect(bw.toBytes(), []);

      bw = getWriter();
      bw.writeDoubleList([1.0]);
      expect(bw.toBytes(), [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 240, 63]);

      bw = getWriter();
      bw.writeDoubleList([1.0], writeLength: false);
      expect(bw.toBytes(), [0, 0, 0, 0, 0, 0, 240, 63]);

      bw = getWriter()
        ..writeByte(0xAA)
        ..writeDoubleList([1.5, -2.25])
        ..writeByte(0xBB);
      var br = fromBytes(bw.toBytes());
      expect(br.readByte(), 0xAA);
      expect(br.readDoubleList(), [1.5, -2.25]);
      expect(br.readByte(), 0xBB);

      bw = getWriter()
        ..writeByte(0xAA)
        ..writeDoubleList([1.5, -2.25], writeLength: false)
        ..writeByte(0xBB);
      br = fromBytes(bw.toBytes());
      expect(br.readByte(), 0xAA);
      expect(br.readDoubleList(2), [1.5, -2.25]);
      expect(br.readByte(), 0xBB);

      final largeDoubles = List.generate(1000, (i) => i * 0.5);
      bw = getWriter()..writeDoubleList(largeDoubles);
      expect(fromBytes(bw.toBytes()).readDoubleList(), largeDoubles);
    });

    test('.writeBoolList()', () {
      var bw = getWriter();
      bw.writeBoolList([]);
      expect(bw.toBytes(), [0, 0, 0, 0]);

      bw = getWriter();
      bw.writeBoolList([], writeLength: false);
      expect(bw.toBytes(), []);

      bw = getWriter();
      bw.writeBoolList([true, false, true]);
      expect(bw.toBytes(), [3, 0, 0, 0, 1, 0, 1]);

      bw = getWriter();
      bw.writeBoolList([true, false, true], writeLength: false);
      expect(bw.toBytes(), [1, 0, 1]);

      bw = getWriter()
        ..writeByte(0xAA)
        ..writeBoolList([true, false, true])
        ..writeByte(0xBB);
      var br = fromBytes(bw.toBytes());
      expect(br.readByte(), 0xAA);
      expect(br.readBoolList(), [true, false, true]);
      expect(br.readByte(), 0xBB);

      bw = getWriter()
        ..writeByte(0xAA)
        ..writeBoolList([true, false, true], writeLength: false)
        ..writeByte(0xBB);
      br = fromBytes(bw.toBytes());
      expect(br.readByte(), 0xAA);
      expect(br.readBoolList(3), [true, false, true]);
      expect(br.readByte(), 0xBB);

      final largeBools = List.generate(5000, (i) => i.isEven);
      bw = getWriter()..writeBoolList(largeBools);
      expect(fromBytes(bw.toBytes()).readBoolList(), largeBools);
    });

    test('.writeStringList()', () {
      var bw = getWriter();
      bw.writeStringList([]);
      expect(bw.toBytes(), [0, 0, 0, 0]);

      bw = getWriter();
      bw.writeStringList([], writeLength: false);
      expect(bw.toBytes(), []);

      bw = getWriter();
      bw.writeStringList(['a', '🧙‍♂️']);
      expect(bw.toBytes(), [
        2, 0, 0, 0, 1, 0, 0, 0, 97, 13, 0, 0, 0, 0xf0, 0x9f, 0xa7, //
        0x99, 0xe2, 0x80, 0x8d, 0xe2, 0x99, 0x82, 0xef, 0xb8, 0x8f, //
      ]);

      bw = getWriter();
      bw.writeStringList(['a', 'ab'], writeLength: false);
      expect(bw.toBytes(), [1, 0, 0, 0, 97, 2, 0, 0, 0, 97, 98]);
    });

    test('.writeList()', () {
      var bw = getWriter();
      bw.writeList(<dynamic>['h', true]);
      expect(bw.toBytes(), [
        2, 0, 0, 0, //
        FrameValueType.stringT, 1, 0, 0, 0, 0x68, //
        FrameValueType.boolT, 1, //
      ]);

      bw = getWriter();
      bw.writeList(<dynamic>['h', true], writeLength: false);
      expect(bw.toBytes(), [
        FrameValueType.stringT, 1, 0, 0, 0, 0x68, //
        FrameValueType.boolT, 1, //
      ]);
    });

    test('.writeMap()', () {
      var bw = getWriter();
      bw.writeMap({true: 'h', 'hi': true});
      expect(bw.toBytes(), [
        2, 0, 0, 0, //
        FrameValueType.boolT, 1, //
        FrameValueType.stringT, 1, 0, 0, 0, 0x68, //
        FrameValueType.stringT, 2, 0, 0, 0, 0x68, 0x69, //
        FrameValueType.boolT, 1, //
      ]);

      bw = getWriter();
      bw.writeMap({true: 'h', 'hi': true}, writeLength: false);
      expect(bw.toBytes(), [
        FrameValueType.boolT, 1, //
        FrameValueType.stringT, 1, 0, 0, 0, 0x68, //
        FrameValueType.stringT, 2, 0, 0, 0, 0x68, 0x69, //
        FrameValueType.boolT, 1, //
      ]);
    });

    group('.writeHiveList()', () {
      final box = MockBox();
      when(() => box.name).thenReturn('Box');

      final obj = TestHiveObject()..init('key', box);

      test('write length', () {
        final list = HiveList(box, objects: [obj]);
        final bw = getWriter();
        bw.writeHiveList(list);

        expect(bw.toBytes(), [
          1, 0, 0, 0, 3, 66, 111, 120, //
          1, 3, 107, 101, 121, //
        ]);
      });

      test('omit length', () {
        final list = HiveList(box, objects: [obj]);
        final bw = getWriter();
        bw.writeHiveList(list, writeLength: false);

        expect(bw.toBytes(), [
          3, 66, 111, 120, //
          1, 3, 107, 101, 121, //
        ]);
      });
    });

    group('.writeFrame()', () {
      test('normal', () {
        for (var i = 0; i < testFrames.length; i++) {
          final frame = testFrames[i];
          final writer = BinaryWriterImpl(testRegistry);
          expect(writer.writeFrame(frame), frameBytes[i].length);
          expect(writer.toBytes(), frameBytes[i]);
        }
      });

      test('encrypted', () {
        for (var i = 0; i < testFrames.length; i++) {
          final frame = testFrames[i];
          final writer = BinaryWriterImpl(testRegistry);
          expect(
            writer.writeFrame(frame, cipher: testCipher),
            frameBytesEncrypted[i].length,
          );
          expect(writer.toBytes(), frameBytesEncrypted[i]);
        }
      });
    });

    group('.write()', () {
      test('null', () {
        var bw = getWriter();
        bw.write(null, withTypeId: false);
        expect(bw.toBytes(), []);

        bw = getWriter();
        bw.write(null, withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.nullT]);
      });

      test('int', () {
        final bd = ByteData(8)..setFloat64(0, 12345, Endian.little);

        var bw = getWriter();
        bw.write(12345, withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write(12345, withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.intT, ...bytes(bd)]);
      });

      test('double', () {
        final bd = ByteData(8)..setFloat64(0, 123.456, Endian.little);

        var bw = getWriter();
        bw.write(123.456, withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write(123.456, withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.doubleT, ...bytes(bd)]);
      });

      test('bool', () {
        var bw = getWriter();
        bw.write(true, withTypeId: false);
        expect(bw.toBytes(), [1]);

        bw = getWriter();
        bw.write(true, withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.boolT, 1]);
      });

      test('string', () {
        var bw = getWriter();
        bw.write('hi', withTypeId: false);
        expect(bw.toBytes(), [2, 0, 0, 0, 0x68, 0x69]);

        bw = getWriter();
        bw.write('hi', withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.stringT, 2, 0, 0, 0, 0x68, 0x69]);
      });

      test('HiveList', () {
        final box = MockBox();
        when(() => box.name).thenReturn('Box');

        final obj = TestHiveObject()..init('key', box);
        final list = HiveList(box, objects: [obj]);
        final bw = getWriter();
        bw.write(list);

        expect(bw.toBytes(), [
          FrameValueType.hiveListT,
          1, 0, 0, 0, 3, 66, 111, 120, //
          1, 3, 107, 101, 121, //
        ]);
      });

      test('byte list', () {
        var bw = getWriter();
        bw.write(Uint8List.fromList([1, 2, 3, 4]), withTypeId: false);
        expect(bw.toBytes(), [4, 0, 0, 0, 1, 2, 3, 4]);

        bw = getWriter();
        bw.write(Uint8List.fromList([1, 2, 3, 4]), withTypeId: true);
        expect(
          bw.toBytes(),
          [FrameValueType.byteListT, 4, 0, 0, 0, 1, 2, 3, 4],
        );
      });

      test('int list', () {
        final bd = ByteData(20)
          ..setUint32(0, 2, Endian.little)
          ..setFloat64(4, 123, Endian.little)
          ..setFloat64(12, 45, Endian.little);

        var bw = getWriter();
        bw.write([123, 45], withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write([123, 45], withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.intListT, ...bytes(bd)]);
      });

      test('double list', () {
        final bd = ByteData(20)
          ..setUint32(0, 2, Endian.little)
          ..setFloat64(4, 123.456, Endian.little)
          ..setFloat64(12, 456.321, Endian.little);

        var bw = getWriter();
        bw.write([123.456, 456.321], withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write([123.456, 456.321], withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.doubleListT, ...bytes(bd)]);
      });

      test('bool list', () {
        final bd = ByteData(6)
          ..setUint32(0, 2, Endian.little)
          ..setUint8(4, 0)
          ..setUint8(5, 1);

        var bw = getWriter();
        bw.write([false, true], withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write([false, true], withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.boolListT, ...bytes(bd)]);
      });

      test('string list', () {
        var bw = getWriter();
        bw.write(['h', 'hi'], withTypeId: false);
        expect(bw.toBytes(), [
          2, 0, 0, 0, //
          1, 0, 0, 0, 0x68, //
          2, 0, 0, 0, 0x68, 0x69, //
        ]);

        bw = getWriter();
        bw.write(['h', 'hi'], withTypeId: true);
        expect(bw.toBytes(), [
          FrameValueType.stringListT, 2, 0, 0, 0, //
          1, 0, 0, 0, 0x68, //
          2, 0, 0, 0, 0x68, 0x69, //
        ]);
      });

      test('list with null', () {
        final bd = ByteData(23)
          ..setUint32(0, 3, Endian.little)
          ..setUint8(4, FrameValueType.intT)
          ..setFloat64(5, 123, Endian.little)
          ..setUint8(13, FrameValueType.intT)
          ..setFloat64(14, 45, Endian.little)
          ..setUint8(22, FrameValueType.nullT);

        var bw = getWriter();
        bw.write([123, 45, null], withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write([123, 45, null], withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.listT, ...bytes(bd)]);
      });

      test('int set', () {
        final bd = ByteData(20)
          ..setUint32(0, 2, Endian.little)
          ..setFloat64(4, 123, Endian.little)
          ..setFloat64(12, 45, Endian.little);

        var bw = getWriter();
        bw.write({123, 45}, withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write({123, 45}, withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.intSetT, ...bytes(bd)]);
      });

      test('double set', () {
        final bd = ByteData(20)
          ..setUint32(0, 2, Endian.little)
          ..setFloat64(4, 123.456, Endian.little)
          ..setFloat64(12, 456.321, Endian.little);

        var bw = getWriter();
        bw.write({123.456, 456.321}, withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write({123.456, 456.321}, withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.doubleSetT, ...bytes(bd)]);
      });

      test('string set', () {
        var bw = getWriter();
        bw.write({'h', 'hi'}, withTypeId: false);
        expect(bw.toBytes(), [
          2, 0, 0, 0, //
          1, 0, 0, 0, 0x68, //
          2, 0, 0, 0, 0x68, 0x69, //
        ]);

        bw = getWriter();
        bw.write({'h', 'hi'}, withTypeId: true);
        expect(bw.toBytes(), [
          FrameValueType.stringSetT, 2, 0, 0, 0, //
          1, 0, 0, 0, 0x68, //
          2, 0, 0, 0, 0x68, 0x69, //
        ]);
      });

      test('set with null', () {
        final bd = ByteData(23)
          ..setUint32(0, 3, Endian.little)
          ..setUint8(4, FrameValueType.intT)
          ..setFloat64(5, 123, Endian.little)
          ..setUint8(13, FrameValueType.intT)
          ..setFloat64(14, 45, Endian.little)
          ..setUint8(22, FrameValueType.nullT);

        var bw = getWriter();
        bw.write({123, 45, null}, withTypeId: false);
        expect(bw.toBytes(), bytes(bd));

        bw = getWriter();
        bw.write({123, 45, null}, withTypeId: true);
        expect(bw.toBytes(), [FrameValueType.setT, ...bytes(bd)]);
      });

      test('map', () {
        var bw = getWriter();
        bw.write({'a': 1}, withTypeId: false);
        expect(fromBytes(bw.toBytes()).readMap(), {'a': 1});

        bw = getWriter();
        bw.write({'a': 1}, withTypeId: true);
        final br = fromBytes(bw.toBytes());
        expect(br.readByte(), FrameValueType.mapT);
        expect(br.readMap(), {'a': 1});
      });

      test('HiveList without typeId', () {
        final box = MockBox();
        when(() => box.name).thenReturn('Box');

        final obj = TestHiveObject()..init('key', box);
        final list = HiveList(box, objects: [obj]);
        final bw = getWriter();
        bw.write(list, withTypeId: false);

        expect(bw.toBytes(), [
          1, 0, 0, 0, 3, 66, 111, 120, //
          1, 3, 107, 101, 121, //
        ]);
      });

      test('custom adapter', () {
        final registry = TypeRegistryImpl()
          ..registerAdapter(_TrackingAdapter(100));
        var bw = BinaryWriterImpl(registry);
        bw.write(const _TrackedValue('custom'), withTypeId: true);
        final decoded =
            BinaryReaderImpl(bw.toBytes(), registry).read() as _TrackedValue;
        expect(decoded.payload, 'custom');

        bw = BinaryWriterImpl(registry);
        bw.write(const _TrackedValue('custom'), withTypeId: false);
        final decodedNoTypeId = _TrackingAdapter(100)
            .read(BinaryReaderImpl(bw.toBytes(), registry));
        expect(decodedNoTypeId.payload, 'custom');

        final extRegistry = TypeRegistryImpl()
          ..registerAdapter(_TrackingAdapter(300));
        bw = BinaryWriterImpl(extRegistry);
        bw.write(const _TrackedValue(42), withTypeId: true);
        final decodedExt =
            BinaryReaderImpl(bw.toBytes(), extRegistry).read() as _TrackedValue;
        expect(decodedExt.payload, 42);

        bw = BinaryWriterImpl(extRegistry);
        bw.write(const _TrackedValue(42), withTypeId: false);
        final decodedExtNoTypeId = _TrackingAdapter(300)
            .read(BinaryReaderImpl(bw.toBytes(), extRegistry));
        expect(decodedExtNoTypeId.payload, 42);
      });

      test('unknown type throws HiveError', () {
        final bw = getWriter();
        expect(() => bw.write(Object()), throwsA(isA<HiveError>()));
      });
    });

    group('.writeKey()', () {
      test('int and string keys', () {
        final bw = getWriter()
          ..writeKey(0)
          ..writeKey(12345)
          ..writeKey(4294967295)
          ..writeKey('myKey')
          ..writeKey('hellö🔑');

        final br = fromBytes(bw.toBytes());
        expect(br.readKey(), 0);
        expect(br.readKey(), 12345);
        expect(br.readKey(), 4294967295);
        expect(br.readKey(), 'myKey');
        expect(br.readKey(), 'hellö🔑');
      });

      test('null key throws ArgumentError', () {
        final bw = getWriter();
        expect(() => bw.writeKey(null), throwsArgumentError);
      });
    });

    group('.writeEncrypted()', () {
      test('sequential frames on single writer', () {
        final writer = BinaryWriterImpl(testRegistry);
        final expectedBytes = <int>[];
        for (var i = 0; i < testFrames.length; i++) {
          final frame = testFrames[i];
          expect(
            writer.writeFrame(frame, cipher: testCipher),
            frameBytesEncrypted[i].length,
          );
          expectedBytes.addAll(frameBytesEncrypted[i]);
        }

        final actualBytes = writer.toBytes();
        expect(actualBytes, expectedBytes);

        final reader = BinaryReaderImpl(actualBytes, testRegistry);
        var offset = 0;
        for (var i = 0; i < testFrames.length; i++) {
          final readFrame = reader.readFrame(
            lazy: false,
            frameOffset: offset,
            cipher: testCipher,
          );
          if (readFrame == null) {
            fail('Expected a non-null Frame');
          }
          expect(readFrame.key, testFrames[i].key);
          if (testFrames[i].deleted) {
            expect(readFrame.deleted, isTrue);
          } else {
            expect(readFrame.value, testFrames[i].value);
          }
          offset += frameBytesEncrypted[i].length;
        }
      });

      test('reuses scratch writer across sequential encrypted writes', () {
        final registry = TypeRegistryImpl();
        final adapter = _TrackingAdapter();
        registry.registerAdapter(adapter);
        final spyCipher = _SpyCipher(testCipher);
        final writer = BinaryWriterImpl(registry);

        final start1 = writer.toBytes().length;
        writer.writeEncrypted(const _TrackedValue('first'), spyCipher);
        final end1 = writer.toBytes().length;

        final start2 = end1;
        writer.writeEncrypted(const _TrackedValue('second'), spyCipher);
        final end2 = writer.toBytes().length;

        final start3 = end2;
        writer.writeEncrypted('no-type-id', spyCipher, withTypeId: false);
        final end3 = writer.toBytes().length;

        expect(adapter.writers.length, 2);
        expect(identical(adapter.writers[0], adapter.writers[1]), isTrue);
        expect(spyCipher.inputBufferLengths, [4096, 4096, 4096]);

        final allBytes = writer.toBytes();
        final decoded1 = _decryptValue(
          allBytes.sublist(start1, end1),
          spyCipher,
          registry,
        ) as _TrackedValue;
        final decoded2 = _decryptValue(
          allBytes.sublist(start2, end2),
          spyCipher,
          registry,
        ) as _TrackedValue;
        final decoded3 = _decryptValue(
          allBytes.sublist(start3, end3),
          spyCipher,
          registry,
          typeId: FrameValueType.stringT,
        );

        expect(decoded1.payload, 'first');
        expect(decoded2.payload, 'second');
        expect(decoded3, 'no-type-id');
      });

      test('retains buffer up to 65536 bytes and shrinks oversized buffers',
          () {
        final registry = TypeRegistryImpl();
        final adapter = _TrackingAdapter();
        registry.registerAdapter(adapter);
        final spyCipher = _SpyCipher(testCipher);
        final writer = BinaryWriterImpl(registry);

        final midLargeBytes = Uint8List(20000);
        final oversizedBytes =
            Uint8List.fromList(List.generate(70000, (i) => i & 0xFF));

        final s0 = writer.toBytes().length;
        writer.writeEncrypted(_TrackedValue(midLargeBytes), spyCipher);
        final e0 = writer.toBytes().length;

        final s1 = e0;
        writer.writeEncrypted(const _TrackedValue('mid'), spyCipher);
        final e1 = writer.toBytes().length;

        final s2 = e1;
        writer.writeEncrypted(_TrackedValue(oversizedBytes), spyCipher);
        final e2 = writer.toBytes().length;

        final s3 = e2;
        writer.writeEncrypted(const _TrackedValue(3.14159), spyCipher);
        final e3 = writer.toBytes().length;

        final s4 = e3;
        writer.writeEncrypted(const _TrackedValue(123456), spyCipher);
        final e4 = writer.toBytes().length;

        expect(adapter.writers.length, 5);
        for (var i = 1; i < adapter.writers.length; i++) {
          expect(identical(adapter.writers[0], adapter.writers[i]), isTrue);
        }

        expect(spyCipher.inputBufferLengths[0], 65536);
        expect(spyCipher.inputBufferLengths[1], 65536);
        expect(spyCipher.inputBufferLengths[2], greaterThan(65536));
        expect(spyCipher.inputBufferLengths[3], 4096);
        expect(spyCipher.inputBufferLengths[4], 4096);

        final allBytes = writer.toBytes();
        expect(
          (_decryptValue(
            allBytes.sublist(s0, e0),
            spyCipher,
            registry,
          ) as _TrackedValue)
              .payload,
          midLargeBytes,
        );
        expect(
          (_decryptValue(
            allBytes.sublist(s1, e1),
            spyCipher,
            registry,
          ) as _TrackedValue)
              .payload,
          'mid',
        );
        expect(
          (_decryptValue(
            allBytes.sublist(s2, e2),
            spyCipher,
            registry,
          ) as _TrackedValue)
              .payload,
          oversizedBytes,
        );
        expect(
          (_decryptValue(
            allBytes.sublist(s3, e3),
            spyCipher,
            registry,
          ) as _TrackedValue)
              .payload,
          3.14159,
        );
        expect(
          (_decryptValue(
            allBytes.sublist(s4, e4),
            spyCipher,
            registry,
          ) as _TrackedValue)
              .payload,
          123456,
        );
      });

      test('resets and shrinks scratch writer if write throws', () {
        final registry = TypeRegistryImpl();
        final adapter = _TrackingAdapter();
        registry.registerAdapter(adapter);
        final spyCipher = _SpyCipher(testCipher);
        final writer = BinaryWriterImpl(registry);

        expect(
          () => writer.writeEncrypted(
            _TrackedValue(
              null,
              onWrite: (scratch) {
                scratch.write(Uint8List(70000));
                throw StateError('boom');
              },
            ),
            spyCipher,
          ),
          throwsStateError,
        );

        final start = writer.toBytes().length;
        writer.writeEncrypted(const _TrackedValue('recovered'), spyCipher);
        final end = writer.toBytes().length;

        expect(adapter.writers.length, 2);
        expect(identical(adapter.writers[0], adapter.writers[1]), isTrue);
        expect(spyCipher.inputBufferLengths.last, 4096);

        final decoded = _decryptValue(
          writer.toBytes().sublist(start, end),
          spyCipher,
          registry,
        ) as _TrackedValue;
        expect(decoded.payload, 'recovered');
      });

      test('handles re-entrant writeEncrypted from a custom adapter', () {
        final registry = TypeRegistryImpl();
        final adapter = _TrackingAdapter();
        registry.registerAdapter(adapter);
        final spyCipher = _SpyCipher(testCipher);
        final writer = BinaryWriterImpl(registry);

        var innerStart = 0;
        var innerEnd = 0;
        writer.writeEncrypted(
          _TrackedValue(
            null,
            onWrite: (scratch) {
              innerStart = writer.toBytes().length;
              writer.writeEncrypted('inner', spyCipher);
              innerEnd = writer.toBytes().length;
              scratch.write('outer');
            },
          ),
          spyCipher,
        );
        final outerEnd = writer.toBytes().length;

        final afterStart = outerEnd;
        writer.writeEncrypted('after', spyCipher);
        final afterEnd = writer.toBytes().length;

        final allBytes = writer.toBytes();
        expect(
          _decryptValue(
            allBytes.sublist(innerStart, innerEnd),
            spyCipher,
            registry,
          ),
          'inner',
        );
        final outerDecoded = _decryptValue(
          allBytes.sublist(innerEnd, outerEnd),
          spyCipher,
          registry,
        ) as _TrackedValue;
        expect(outerDecoded.payload, 'outer');
        expect(
          _decryptValue(
            allBytes.sublist(afterStart, afterEnd),
            spyCipher,
            registry,
          ),
          'after',
        );
      });
    });

    test('.writeTypeId()', () {
      for (var i = 0; i <= TypeRegistryImpl.maxExtendedTypeId; i++) {
        final bw = getWriter();
        bw.writeTypeId(i);
        if (i < 256) {
          expect(bw.toBytes(), [i]);
        } else {
          final bd = ByteData(3)
            ..setUint8(0, FrameValueType.typeIdExtension)
            ..setUint16(1, i, Endian.little);
          expect(bw.toBytes(), bytes(bd));
        }
      }
    });
  });
}
