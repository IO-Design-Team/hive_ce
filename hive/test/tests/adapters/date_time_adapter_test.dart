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
      when(binaryReader.readDouble)
          .thenReturn(now.microsecondsSinceEpoch / 1000);

      final date = DateTimeAdapter().read(binaryReader);
      verify(binaryReader.readDouble);
      expect(date, now);
    });

    test('.write()', () {
      final now = DateTime.now();
      final binaryWriter = MockBinaryWriter();

      DateTimeAdapter().write(binaryWriter, now);
      verify(
        () => binaryWriter.writeDouble(now.microsecondsSinceEpoch / 1000),
      );
    });
  });

  group('DateTimeWithTimezoneAdapter', () {
    group('.read()', () {
      test('local', () {
        final now = DateTime.now();
        final binaryReader = MockBinaryReader();
        when(binaryReader.readDouble)
            .thenReturn(now.microsecondsSinceEpoch / 1000);
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
            .thenReturn(now.microsecondsSinceEpoch / 1000);
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
          () => binaryWriter.writeDouble(now.microsecondsSinceEpoch / 1000),
          () => binaryWriter.writeBool(false),
        ]);
      });

      test('UTC', () {
        final now = DateTime.now().toUtc();
        final binaryWriter = MockBinaryWriter();

        DateTimeWithTimezoneAdapter().write(binaryWriter, now);
        verifyInOrder([
          () => binaryWriter.writeDouble(now.microsecondsSinceEpoch / 1000),
          () => binaryWriter.writeBool(true),
        ]);
      });
    });
  });
}
