import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/object/hive_object.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
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
      expect(output2, contains(BinaryWriterImpl.intWarning));

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
