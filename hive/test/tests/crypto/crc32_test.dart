import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/src/crypto/crc32.dart';
import 'package:test/test.dart';

/// Bit-at-a-time CRC32 without lookup tables, used as an independent
/// reference.
int _referenceCrc32(Uint8List bytes, int crc, int offset, int length) {
  crc = (crc ^ 0xffffffff) & 0xffffffff;
  for (var i = offset; i < offset + length; i++) {
    crc ^= bytes[i];
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

Uint8List _randomBytes(Random random, int length) =>
    Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));

void main() {
  group('Crc32', () {
    test('compute', () {
      expect(Crc32.compute(Uint8List(0)), equals(0));
      expect(
        Crc32.compute(Uint8List.fromList('123456789'.codeUnits)),
        0xcbf43926,
      );

      final crc = Crc32.compute(Uint8List.fromList('12345'.codeUnits));
      expect(
        Crc32.compute(Uint8List.fromList('6789'.codeUnits), crc: crc),
        equals(0xcbf43926),
      );
    });

    test('matches the bitwise reference for every offset, length and crc', () {
      final random = Random(42);
      final bytes = _randomBytes(random, 512);
      final crcs = [0, 1, 0x7fffffff, 0x80000000, 0xffffffff, 0x1234abcd];
      for (final crc in crcs) {
        for (var offset = 0; offset < 16; offset++) {
          for (var length = 0; length <= 300; length++) {
            expect(
              Crc32.compute(bytes, crc: crc, offset: offset, length: length),
              _referenceCrc32(bytes, crc, offset, length),
              reason: 'crc: $crc, offset: $offset, length: $length',
            );
          }
        }
      }
    });

    test('matches the bitwise reference on unaligned views', () {
      final random = Random(7);
      final backing = _randomBytes(random, 4096);
      for (var start = 1; start < 8; start++) {
        final view = Uint8List.view(backing.buffer, start, 4000);
        final crc = random.nextInt(0xffffffff);
        expect(
          Crc32.compute(view, crc: crc),
          _referenceCrc32(view, crc, 0, view.length),
          reason: 'view starting at $start',
        );
      }
    });

    test('matches the bitwise reference on a large buffer', () {
      final bytes = _randomBytes(Random(1), 1 << 20);
      expect(Crc32.compute(bytes), _referenceCrc32(bytes, 0, 0, bytes.length));
    });

    test('chaining equals a single pass', () {
      final bytes = _randomBytes(Random(3), 10000);
      var crc = 0;
      for (var offset = 0; offset < bytes.length; offset += 333) {
        final length = min(333, bytes.length - offset);
        crc = Crc32.compute(bytes, crc: crc, offset: offset, length: length);
      }
      expect(crc, Crc32.compute(bytes));
    });
  });
}
