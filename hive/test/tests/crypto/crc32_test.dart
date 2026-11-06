import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/src/crypto/crc32.dart';
import 'package:test/test.dart';

int _bitwiseCrc32(Uint8List bytes, int crc, int offset, int length) {
  crc ^= 0xffffffff;
  for (var i = offset; i < offset + length; i++) {
    crc ^= bytes[i];
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}

void main() {
  group('Crc32', () {
    final random = Random(42);
    final bytes =
        Uint8List.fromList(List.generate(512, (_) => random.nextInt(256)));

    void expectBitwise(List<int> crcs, int maxOffset, int maxLength) {
      for (final crc in crcs) {
        for (var offset = 0; offset < maxOffset; offset++) {
          for (var length = 0; length <= maxLength; length++) {
            expect(
              Crc32.compute(bytes, crc: crc, offset: offset, length: length),
              _bitwiseCrc32(bytes, crc, offset, length),
            );
          }
        }
      }
    }

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

    test('matches a bitwise implementation', () {
      expectBitwise([0, 0x80000000, 0xffffffff, 0x1234abcd], 16, 300);
    });

    test('supports key CRCs outside of 32 bits', () {
      expectBitwise([0x100000000, 0x1234567890ab, 0x1fffffffffffff], 8, 40);
    });
  });
}
