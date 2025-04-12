import 'dart:typed_data';

import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/binary/raw_object_reader.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:test/test.dart';

RawObjectReader fromByteData(ByteData byteData) {
  return RawObjectReader(byteData.buffer.asUint8List(), TypeRegistryImpl());
}

RawObjectReader fromBytes(List<int> bytes) {
  return RawObjectReader(Uint8List.fromList(bytes), TypeRegistryImpl());
}

void main() {
  group('RawObjectReader', () {
    test('primitive', () {
      final br = fromByteData(
        ByteData(9)
          ..setUint8(0, FrameValueType.intT)
          ..setFloat64(1, 123, Endian.little),
      );

      expect(br.read(), 123);
    });

    test('custom object', () {
      final br = fromByteData(
        ByteData(27)
          ..setUint8(0, 200) // object type id
          ..setUint8(1, 4) // object field count
          ..setUint8(2, 0) // field index
          ..setUint8(3, FrameValueType.intT) // field type id
          ..setFloat64(4, 12345, Endian.little) // field value
          ..setUint8(12, 1) // field index
          ..setUint8(13, FrameValueType.intT) // field type id
          ..setFloat64(14, 123, Endian.little) // field value
          ..setUint8(22, 2) // field index
          ..setUint8(23, FrameValueType.nullT) // field type id
          ..setUint8(24, 3) // field index
          ..setUint8(25, 201) // enum type id
          ..setUint8(26, 1), // enum index
      );

      expect(
        br.read(),
        isA<RawObject>().having((o) => o.typeId, 'typeId', 200).having(
          (o) => o.fields,
          'fields',
          [
            isA<RawField>()
                .having((f) => f.index, 'index', 0)
                .having((f) => f.value, 'value', 12345),
            isA<RawField>()
                .having((f) => f.index, 'index', 1)
                .having((f) => f.value, 'value', 123),
            isA<RawField>()
                .having((f) => f.index, 'index', 2)
                .having((f) => f.value, 'value', null),
            isA<RawField>()
                .having((f) => f.index, 'index', 3) //
                .having(
                  (f) => f.value,
                  'value',
                  isA<RawEnum>()
                      .having((e) => e.typeId, 'typeId', 201)
                      .having((e) => e.index, 'index', 1),
                ),
          ],
        ),
      );
    });
  });
}
