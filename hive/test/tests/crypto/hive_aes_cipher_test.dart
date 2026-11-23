import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/crypto/aes_cbc_pkcs7.dart';
import 'package:test/test.dart';

import 'message.dart';

class _StaticIvCipher extends HiveAesCipher {
  _StaticIvCipher(
    super.key,
    this.fixedIv, {
    required this.onGenerateIv,
  });

  final Uint8List fixedIv;
  final void Function() onGenerateIv;

  @override
  Uint8List generateIv() {
    onGenerateIv();
    return fixedIv;
  }
}

void main() {
  final corruptedPadError = isA<ArgumentError>().having(
    (e) => e.message,
    'message',
    'Invalid or corrupted pad block',
  );

  group('HiveAesCipher', () {
    test('validates key length and byte range', () {
      expect(() => HiveAesCipher(List.filled(31, 0)), throwsArgumentError);
      expect(() => HiveAesCipher(List.filled(33, 0)), throwsArgumentError);
      expect(
        () => HiveAesCipher(<int>[...List.filled(31, 0), -1]),
        throwsArgumentError,
      );
      expect(
        () => HiveAesCipher(<int>[...List.filled(31, 0), 256]),
        throwsArgumentError,
      );
    });

    test('.generateIv() returns distinct 16-byte buffers', () {
      final cipher = HiveAesCipher(key);
      final iv1 = cipher.generateIv();
      final iv1Copy = Uint8List.fromList(iv1);
      final iv2 = cipher.generateIv();

      expect(iv1.length, 16);
      expect(iv2.length, 16);
      expect(identical(iv1, iv2), isFalse);
      expect(iv1, iv1Copy);
      expect(iv1, isNot(iv2));
    });

    test(
      'round-trips empty, short, block-aligned, and multi-block payloads',
      () {
        final cipher = HiveAesCipher(key);
        final cbc = AesCbcPkcs7(key);

        final lengths = <int>[
          for (var len = 0; len <= 64; len++) len,
          message.length,
        ];

        for (final len in lengths) {
          final input = Uint8List.sublistView(message, 0, len);
          final encrypted = Uint8List(cipher.maxEncryptedSize(input));
          final encLen = cipher.encrypt(input, 0, len, encrypted, 0);

          final usedIv = Uint8List.sublistView(encrypted, 0, 16);
          final expectedCiphertext = Uint8List(encLen - 16);
          final cbcLen = cbc.encrypt(
            usedIv,
            input,
            0,
            len,
            expectedCiphertext,
            0,
          );
          expect(encLen - 16, cbcLen);
          expect(
            Uint8List.sublistView(encrypted, 16, encLen),
            expectedCiphertext,
          );

          final decrypted = Uint8List(encLen);
          final decLen = cipher.decrypt(encrypted, 0, encLen, decrypted, 0);
          expect(decLen, len);
          expect(Uint8List.sublistView(decrypted, 0, decLen), input);
        }
      },
    );

    test('respects non-zero inpOff and outOff for encrypt and decrypt', () {
      final cipher = HiveAesCipher(key);
      const inpOff = 7;
      const encOutOff = 13;
      const decOutOff = 17;

      for (final len in <int>[0, 1, 15, 16, 17, 64, 150]) {
        final inpBuf = Uint8List(inpOff + len + 5)
          ..fillRange(0, inpOff + len + 5, 0xaa);
        inpBuf.setRange(inpOff, inpOff + len, message, 20);

        final encBuf = Uint8List(encOutOff + len + 48)
          ..fillRange(0, encOutOff + len + 48, 0xbb);
        final encLen = cipher.encrypt(inpBuf, inpOff, len, encBuf, encOutOff);

        expect(encBuf.sublist(0, encOutOff), List.filled(encOutOff, 0xbb));
        expect(
          encBuf.sublist(encOutOff + encLen),
          List.filled(encBuf.length - encOutOff - encLen, 0xbb),
        );

        final decBuf = Uint8List(decOutOff + encLen + 9)
          ..fillRange(0, decOutOff + encLen + 9, 0xcc);
        final decLen = cipher.decrypt(
          encBuf,
          encOutOff,
          encLen,
          decBuf,
          decOutOff,
        );
        expect(decLen, len);
        expect(
          decBuf.sublist(decOutOff, decOutOff + decLen),
          inpBuf.sublist(inpOff, inpOff + len),
        );
        expect(decBuf.sublist(0, decOutOff), List.filled(decOutOff, 0xcc));
      }
    });

    test('calls generateIv() override on subclasses', () {
      final fixedIv = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
      var generateIvCalls = 0;
      final cipher = _StaticIvCipher(
        key,
        fixedIv,
        onGenerateIv: () => generateIvCalls++,
      );
      final cbc = AesCbcPkcs7(key);
      const inpOff = 5;
      const outOff = 9;
      const decOutOff = 11;
      const len = 37;
      final inpBuf = Uint8List(inpOff + len + 3)
        ..fillRange(0, inpOff + len + 3, 0xaa);
      inpBuf.setRange(inpOff, inpOff + len, message, 12);

      final out1 = Uint8List(outOff + len + 48)
        ..fillRange(0, outOff + len + 48, 0xbb);
      final out2 = Uint8List(outOff + len + 48)
        ..fillRange(0, outOff + len + 48, 0xbb);
      final len1 = cipher.encrypt(inpBuf, inpOff, len, out1, outOff);
      final len2 = cipher.encrypt(inpBuf, inpOff, len, out2, outOff);

      expect(generateIvCalls, 2);
      expect(out1.sublist(outOff, outOff + 16), fixedIv);
      expect(
        out1.sublist(outOff, outOff + len1),
        out2.sublist(outOff, outOff + len2),
      );
      expect(out1.sublist(0, outOff), List.filled(outOff, 0xbb));
      expect(
        out1.sublist(outOff + len1),
        List.filled(out1.length - outOff - len1, 0xbb),
      );

      final expected = Uint8List(len1 - 16);
      cbc.encrypt(fixedIv, inpBuf, inpOff, len, expected, 0);
      expect(out1.sublist(outOff + 16, outOff + len1), expected);

      final decrypted = Uint8List(decOutOff + len1 + 4)
        ..fillRange(0, decOutOff + len1 + 4, 0xcc);
      final decLen = cipher.decrypt(out1, outOff, len1, decrypted, decOutOff);
      expect(decLen, len);
      expect(
        decrypted.sublist(decOutOff, decOutOff + decLen),
        inpBuf.sublist(inpOff, inpOff + len),
      );
      expect(decrypted.sublist(0, decOutOff), List.filled(decOutOff, 0xcc));
    });

    test('decrypt throws on truncated or corrupted ciphertext', () {
      final cipher = HiveAesCipher(key);
      final input = Uint8List.sublistView(message, 0, 23);
      final encrypted = Uint8List(cipher.maxEncryptedSize(input));
      final encLen = cipher.encrypt(input, 0, input.length, encrypted, 0);
      final out = Uint8List(encLen);

      for (final badLen in <int>[0, 8, 16, 17, 31, encLen - 1]) {
        expect(
          () => cipher.decrypt(encrypted, 0, badLen, out, 0),
          throwsA(corruptedPadError),
        );
      }

      // Corrupt last ciphertext byte to corrupt PKCS7 padding.
      encrypted[encLen - 1] ^= 0xff;
      expect(
        () => cipher.decrypt(encrypted, 0, encLen, out, 0),
        throwsA(corruptedPadError),
      );
    });
  });
}
