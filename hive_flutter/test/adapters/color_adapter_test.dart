import 'dart:ui' show Color;

import 'package:hive_ce_flutter/adapters.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';

import '../mocks.dart';

void main() {
  final registry = TypeRegistryImpl();

  group('ColorAdapter', () {
    group('.read()', () {
      test('Color.value', () {
        const color = Color(0xFF000000);
        final writer = BinaryWriterImpl(registry);
        // ignore: deprecated_member_use
        writer.writeInt(color.value);

        final reader = BinaryReaderImpl(writer.toBytes(), registry);
        final readColor = ColorAdapter().read(reader);
        expect(readColor, color);
      });

      test('HiveColor', () {
        const color = Color(0xFF000000);
        final writer = BinaryWriterImpl(registry);
        ColorAdapter().write(writer, color);

        final reader = BinaryReaderImpl(writer.toBytes(), registry);
        final readColor = ColorAdapter().read(reader);
        expect(readColor, color);
      });
    });

    test('.write()', () {
      const color = Color(0xAABBCCDD);
      final BinaryWriter writer = MockBinaryWriter();

      ColorAdapter().write(writer, color);
      verify(writer.write(color.a));
      verify(writer.write(color.r));
      verify(writer.write(color.g));
      verify(writer.write(color.b));
      verify(writer.write(color.colorSpace.index));
    });
  });
}
