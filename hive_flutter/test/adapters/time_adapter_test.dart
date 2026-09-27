import 'package:flutter/material.dart' as flutter show TimeOfDay;
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:material_ui/material_ui.dart' as material_ui show TimeOfDay;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('TimeOfDayAdapter', () {
    late flutter.TimeOfDay time;
    late int totalMinutes;

    setUp(() {
      time = const flutter.TimeOfDay(hour: 8, minute: 0);
      totalMinutes = time.hour * 60 + time.minute;
    });

    test('.read()', () {
      final BinaryReader binaryReader = MockBinaryReader();
      when(binaryReader.readInt()).thenReturn(totalMinutes);

      final readTime = const TimeOfDayAdapter().read(binaryReader);
      verify(binaryReader.readInt()).called(1);
      expect(readTime, time);
    });

    test('.write()', () {
      final BinaryWriter binaryWriter = MockBinaryWriter();

      const TimeOfDayAdapter().write(binaryWriter, time);
      verify(binaryWriter.writeInt(totalMinutes));
    });
  });

  group('TimeOfDayAdapter and MaterialUiTimeOfDayAdapter compatibility', () {
    final flutterRegistry = TypeRegistryImpl()
      ..registerAdapter(const TimeOfDayAdapter());
    final materialUiRegistry = TypeRegistryImpl()
      ..registerAdapter(const MaterialUiTimeOfDayAdapter());

    test('flutter to material_ui', () {
      const time = flutter.TimeOfDay(hour: 13, minute: 37);
      final writer = BinaryWriterImpl(flutterRegistry)..write(time);

      final reader = BinaryReaderImpl(writer.toBytes(), materialUiRegistry);
      expect(reader.read(), const material_ui.TimeOfDay(hour: 13, minute: 37));
    });

    test('material_ui to flutter', () {
      const time = material_ui.TimeOfDay(hour: 13, minute: 37);
      final writer = BinaryWriterImpl(materialUiRegistry)..write(time);

      final reader = BinaryReaderImpl(writer.toBytes(), flutterRegistry);
      expect(reader.read(), const flutter.TimeOfDay(hour: 13, minute: 37));
    });
  });
}
