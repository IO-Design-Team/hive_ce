// This is a test
// ignore_for_file: rexios_lints/prefer_timestamps
import 'package:hive_ce/src/adapters/date_time_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('DateTimeAdapter', () {
    test('.read()', () {
      final now = DateTime.now();
      final binaryReader = MockBinaryReader();
      when(binaryReader.readInt).thenReturn(now.millisecondsSinceEpoch);

      final date = DateTimeAdapter().read(binaryReader);
      verify(binaryReader.readInt);
      expect(date, now.subtract(Duration(microseconds: now.microsecond)));
    });

    test('.write()', () {
      final now = DateTime.now();
      final binaryWriter = MockBinaryWriter();

      DateTimeAdapter().write(binaryWriter, now);
      verify(() => binaryWriter.writeInt(now.millisecondsSinceEpoch));
    });
  });

  group('DateTimeWithTimezoneAdapter', () {
    group('.read()', () {
      test('local', () {
        final now = DateTime.now();
        final binaryReader = MockBinaryReader();
        when(binaryReader.readDouble)
            .thenReturn(now.millisecondsSinceEpoch + now.microsecond / 1000);
        when(binaryReader.readBool).thenReturn(false);

        final date = DateTimeWithTimezoneAdapter().read(binaryReader);
        verifyInOrder([
          binaryReader.readDouble,
          binaryReader.readBool,
        ]);
        expect(date, now);
      });

      test('UTC', () {
        final now = DateTime.now().toUtc();
        final binaryReader = MockBinaryReader();
        when(binaryReader.readDouble)
            .thenReturn(now.millisecondsSinceEpoch + now.microsecond / 1000);
        when(binaryReader.readBool).thenReturn(true);

        final date = DateTimeWithTimezoneAdapter().read(binaryReader);
        verifyInOrder([
          binaryReader.readDouble,
          binaryReader.readBool,
        ]);
        expect(date, now);
        expect(date.isUtc, true);
      });
    });

    group('.write()', () {
      test('local', () {
        final now = DateTime.now();
        final binaryWriter = MockBinaryWriter();

        DateTimeWithTimezoneAdapter().write(binaryWriter, now);
        verifyInOrder([
          () => binaryWriter.writeDouble(
                now.millisecondsSinceEpoch + now.microsecond / 1000,
              ),
          () => binaryWriter.writeBool(false),
        ]);
      });

      test('UTC', () {
        final now = DateTime.now().toUtc();
        final binaryWriter = MockBinaryWriter();

        DateTimeWithTimezoneAdapter().write(binaryWriter, now);
        verifyInOrder([
          () => binaryWriter.writeDouble(
                now.millisecondsSinceEpoch + now.microsecond / 1000,
              ),
          () => binaryWriter.writeBool(true),
        ]);
      });
    });
  });
}
