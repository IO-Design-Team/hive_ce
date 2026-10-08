import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/src/adapters/duration_adapter.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('DurationAdapter', () {
    test('.read()', () {
      final duration = Duration(seconds: 30, microseconds: 7);
      final binaryReader = MockBinaryReader();
      when(binaryReader.readDouble).thenReturn(duration.inMilliseconds + 0.007);

      final duration2 = DurationAdapter().read(binaryReader);
      verify(binaryReader.readDouble);
      expect(duration2, duration);
    });

    test('.write()', () {
      final duration = Duration(seconds: 30, microseconds: 7);
      final binaryWriter = MockBinaryWriter();

      DurationAdapter().write(binaryWriter, duration);
      verify(() => binaryWriter.writeDouble(duration.inMilliseconds + 0.007));
    });

    group('binary compatibility', () {
      // Microseconds of the last three are inexact on web
      final wholeMillis = [
        Duration.zero,
        Duration(seconds: 30),
        Duration(milliseconds: -1500),
        Duration(days: 365 * 1000, milliseconds: 1),
        Duration(milliseconds: 1234567890123457),
        Duration(milliseconds: -1234567890123457),
        Duration(milliseconds: 9007199254740991),
      ];

      test('reads data written by 2.20', () {
        for (final duration in wholeMillis) {
          final millis = duration.inMilliseconds;
          expect(_read(_legacyBytes(millis)), Duration(milliseconds: millis));
        }
      });

      test('writes whole milliseconds identically to 2.20', () {
        for (final duration in wholeMillis) {
          expect(_write(duration), _legacyBytes(duration.inMilliseconds));
        }
      });

      test('round trips microseconds exactly under ~278 years', () {
        final random = Random(0);
        final durations = [
          Duration(milliseconds: 1500, microseconds: 7),
          Duration(microseconds: -1),
          Duration(microseconds: -1500),
          Duration(milliseconds: _preciseMillis - 1, microseconds: 999),
          Duration(milliseconds: -_preciseMillis + 1, microseconds: -999),
          for (var i = 0; i < 10000; i++)
            Duration(
              milliseconds:
                  ((random.nextDouble() * 2 - 1) * _preciseMillis).truncate(),
              microseconds: random.nextInt(1999) - 999,
            ),
        ];

        for (final duration in durations) {
          expect(_read(_write(duration)), duration);
        }
      });

      test('keeps 2.20 behavior beyond ~278 years', () {
        final durations = [
          Duration(milliseconds: _preciseMillis, microseconds: 1),
          Duration(days: 365 * 300, microseconds: 999),
          Duration(milliseconds: -1234567890123457, microseconds: -1),
        ];

        for (final duration in durations) {
          final millis = duration.inMilliseconds;
          expect(_write(duration), _legacyBytes(millis));
          expect(_read(_write(duration)), Duration(milliseconds: millis));
        }
      });
    });
  });
}

const _preciseMillis = 8796093022208;

Uint8List _legacyBytes(int millis) =>
    (BinaryWriterImpl(TypeRegistryImpl.nullImpl)..writeInt(millis)).toBytes();

Uint8List _write(Duration duration) {
  final writer = BinaryWriterImpl(TypeRegistryImpl.nullImpl);
  DurationAdapter().write(writer, duration);
  return writer.toBytes();
}

Duration _read(Uint8List bytes) =>
    DurationAdapter().read(BinaryReaderImpl(bytes, TypeRegistryImpl.nullImpl));
