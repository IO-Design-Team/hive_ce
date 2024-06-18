import 'dart:typed_data';

import 'package:hive_ce/src/adapters/big_int_adapter.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:test/test.dart';

void main() {
  group('BigIntAdapter', () {
    group('reads', () {
      test('positive BigInts', () {
        final numberStr = '123456789123456789';
        final bytes =
            Uint8List.fromList([numberStr.length, ...numberStr.codeUnits]);
        final reader = BinaryReaderImpl(bytes, TypeRegistryImpl.nullImpl);
        expect(BigIntAdapter().read(reader), BigInt.parse(numberStr));
      });

      test('negative BigInts', () {
        final numberStr = '-123456789123456789';
        final bytes =
            Uint8List.fromList([numberStr.length, ...numberStr.codeUnits]);
        final reader = BinaryReaderImpl(bytes, TypeRegistryImpl.nullImpl);
        expect(BigIntAdapter().read(reader), BigInt.parse(numberStr));
      });
    });

    test('writes BigInts', () {
      final numberStr = '123456789123456789';
      final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl);
      BigIntAdapter().write(writer, BigInt.parse(numberStr));
      expect(writer.toBytes(), [numberStr.length, ...numberStr.codeUnits]);
    });
  });
}
