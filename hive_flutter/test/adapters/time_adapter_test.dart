import 'package:flutter/material.dart' show TimeOfDay;
import 'package:hive_ce_flutter/adapters.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('TimeOfDayAdapter', () {
    late TimeOfDay time;
    late int totalMinutes;

    setUp(() {
      time = const TimeOfDay(hour: 8, minute: 0);
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
}
