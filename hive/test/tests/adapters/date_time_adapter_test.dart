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
        when(binaryReader.readInt).thenReturn(now.millisecondsSinceEpoch);
        when(binaryReader.readBool).thenReturn(false);

        final date = DateTimeWithTimezoneAdapter().read(binaryReader);
        verifyInOrder([
          binaryReader.readInt,
          binaryReader.readBool,
        ]);
        expect(date, now.subtract(Duration(microseconds: now.microsecond)));
      });

      test('UTC', () {
        final now = DateTime.now().toUtc();
        final binaryReader = MockBinaryReader();
        when(binaryReader.readInt).thenReturn(now.millisecondsSinceEpoch);
        when(binaryReader.readBool).thenReturn(true);

        final date = DateTimeWithTimezoneAdapter().read(binaryReader);
        verifyInOrder([
          binaryReader.readInt,
          binaryReader.readBool,
        ]);
        expect(date, now.subtract(Duration(microseconds: now.microsecond)));
        expect(date.isUtc, true);
      });
    });

    group('.write()', () {
      test('local', () {
        final now = DateTime.now();
        final binaryWriter = MockBinaryWriter();

        DateTimeWithTimezoneAdapter().write(binaryWriter, now);
        verifyInOrder([
          () => binaryWriter.writeInt(now.millisecondsSinceEpoch),
          () => binaryWriter.writeBool(false),
        ]);
      });

      test('UTC', () {
        final now = DateTime.now().toUtc();
        final binaryWriter = MockBinaryWriter();

        DateTimeWithTimezoneAdapter().write(binaryWriter, now);
        verifyInOrder([
          () => binaryWriter.writeInt(now.millisecondsSinceEpoch),
          () => binaryWriter.writeBool(true),
        ]);
      });
    });
  });
}
