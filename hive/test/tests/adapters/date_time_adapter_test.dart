// This is a test
// ignore_for_file: rexios_lints/prefer_timestamps
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/src/adapters/date_time_adapter.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
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

    group('binary compatibility', () {
      final wholeMillis = [
        DateTime.utc(2026, 10, 7, 12, 30, 15, 123),
        DateTime(2026, 10, 7, 12, 30, 15, 123),
        DateTime.utc(1969, 12, 31, 23, 59, 59, 999),
        DateTime.utc(1600, 6, 15, 1, 2, 3, 4),
        DateTime.utc(1),
        DateTime.utc(9999, 12, 31, 23, 59, 59, 999),
        DateTime.fromMillisecondsSinceEpoch(_maxMillis, isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(-_maxMillis, isUtc: true),
      ];

      test('reads data written by 2.20', () {
        for (final date in wholeMillis) {
          final read = _read(_legacyBytes(date));
          expect(read, date);
          expect(read.isUtc, date.isUtc);
        }
      });

      test('writes whole milliseconds identically to 2.20', () {
        for (final date in wholeMillis) {
          expect(_write(date), _legacyBytes(date));
        }
      });

      test('round trips microseconds exactly between 1691 and 2248', () {
        final random = Random(0);
        final dates = [
          DateTime.utc(2026, 10, 3, 12, 0, 0, 0, 1),
          DateTime.utc(1970, 1, 1, 0, 0, 0, 0, 1),
          DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999),
          DateTime.utc(1969, 12, 31, 23, 59, 59, 998, 500),
          DateTime.utc(2110, 5, 22, 13, 24, 37, 221, 776),
          DateTime.utc(1828, 3, 4, 5, 6, 7, 8, 9),
          DateTime.utc(1692, 1, 1, 0, 0, 0, 0, 1),
          DateTime.utc(2247, 12, 31, 23, 59, 59, 999, 999),
          DateTime(2000, 1, 1, 0, 0, 0, 0, 999),
          for (var i = 0; i < 10000; i++)
            DateTime.fromMicrosecondsSinceEpoch(
              ((random.nextDouble() * 2 - 1) * _preciseMillis).truncate() *
                      1000 +
                  random.nextInt(1000),
              isUtc: true,
            ),
        ];

        for (final date in dates) {
          expect(_read(_write(date)), date);
        }
      });

      test('is never less precise than 2.20 outside 1691 to 2248', () {
        final random = Random(0);
        final dates = [
          DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999),
          DateTime.utc(2249, 1, 1, 0, 0, 0, 0, 1),
          DateTime.utc(1690, 12, 31, 23, 59, 59, 999, 999),
          for (var i = 0; i < 10000; i++)
            DateTime.fromMillisecondsSinceEpoch(
              (random.nextBool() ? 1 : -1) *
                  (_preciseMillis +
                      (random.nextDouble() * (_maxMillis - _preciseMillis - 1))
                          .floor()),
              isUtc: true,
            ).add(Duration(microseconds: random.nextInt(1000))),
        ];

        for (final date in dates) {
          final error = _read(_write(date)).difference(date).abs();
          expect(
            error,
            lessThanOrEqualTo(Duration(microseconds: date.microsecond)),
          );
        }
      });
    });
  });
}

const _maxMillis = 8640000000000000;
const _preciseMillis = 8796093022208;

Uint8List _legacyBytes(DateTime date) =>
    (BinaryWriterImpl(TypeRegistryImpl.nullImpl)
          ..writeInt(date.millisecondsSinceEpoch)
          ..writeBool(date.isUtc))
        .toBytes();

Uint8List _write(DateTime date) {
  final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl);
  DateTimeWithTimezoneAdapter().write(writer, date);
  return writer.toBytes();
}

DateTime _read(Uint8List bytes) => DateTimeWithTimezoneAdapter()
    .read(BinaryReaderImpl(bytes, TypeRegistryImpl.nullImpl));
