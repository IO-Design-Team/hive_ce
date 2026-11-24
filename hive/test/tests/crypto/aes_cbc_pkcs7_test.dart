import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_cbc_pkcs7.dart';
import 'package:hive_ce/src/crypto/aes_engine.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

import 'message.dart';

PaddedBlockCipherImpl getCipher() {
  final pcCipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  pcCipher.init(
    true,
    PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(key), iv),
      null,
    ),
  );
  return pcCipher;
}

Uint8List _expectedCbcPkcs7(Uint8List input) {
  if (input.isNotEmpty) {
    return getCipher().process(input);
  }
  final block = Uint8List(aesBlockSize);
  for (var i = 0; i < aesBlockSize; i++) {
    block[i] = aesBlockSize ^ iv[i];
  }
  final out = Uint8List(aesBlockSize);
  (AESEngine()..init(true, KeyParameter(key))).processBlock(block, 0, out, 0);
  return out;
}

Uint8List _encryptRawBlock(Uint8List plainBlock) =>
    getCipher().process(plainBlock).view(0, aesBlockSize);

void main() {
  final corruptedPadError = isA<ArgumentError>().having(
    (e) => e.message,
    'message',
    'Invalid or corrupted pad block',
  );

  group('AesCbcPkcs7', () {
    test('.encrypt()', () {
      final out = Uint8List(1100);
      final cipher = AesCbcPkcs7(key);
      for (var i = 0; i < 1000; i++) {
        final input = message.view(0, i);
        final outLen = cipher.encrypt(iv, input, 0, i, out, 0);
        final pcOut = _expectedCbcPkcs7(input);

        expect(out.view(0, outLen), pcOut);
      }
    });

    test('.decrypt()', () {
      final out = Uint8List(1100);
      final cipher = AesCbcPkcs7(key);
      for (var i = 0; i < 1000; i++) {
        final input = message.view(0, i);
        final encrypted = _expectedCbcPkcs7(input);
        final outLen = cipher.decrypt(
          iv,
          encrypted,
          0,
          encrypted.length,
          out,
          0,
        );
        expect(out.view(0, outLen), input);
      }
    });

    test('supports non-zero offsets and in-place operation', () {
      final cipher = AesCbcPkcs7(key);

      for (final len in [0, 1, 15, 16, 17, 32, 64]) {
        const inpOff = 13;
        const outOff = 19;
        const decOutOff = 5;
        final inpBuf = Uint8List(inpOff + len + 5)
          ..fillRange(0, inpOff + len + 5, 0xee)
          ..setRange(inpOff, inpOff + len, message, 50);
        final expected = _expectedCbcPkcs7(inpBuf.view(inpOff, len));

        final outBuf = Uint8List(outOff + expected.length + 11)
          ..fillRange(0, outOff + expected.length + 11, 0xcc);
        final encLen = cipher.encrypt(iv, inpBuf, inpOff, len, outBuf, outOff);
        expect(encLen, expected.length);
        expect(outBuf.view(outOff, encLen), expected);
        expect(outBuf.view(0, outOff), List.filled(outOff, 0xcc));
        expect(outBuf.view(outOff + encLen, 11), List.filled(11, 0xcc));

        final decBuf = Uint8List(decOutOff + encLen + 9)
          ..fillRange(0, decOutOff + encLen + 9, 0xdd);
        final decLen = cipher.decrypt(
          iv,
          outBuf,
          outOff,
          encLen,
          decBuf,
          decOutOff,
        );
        expect(decLen, len);
        expect(decBuf.view(decOutOff, decLen), inpBuf.view(inpOff, len));
        expect(decBuf.view(0, decOutOff), List.filled(decOutOff, 0xdd));
        expect(decBuf.view(decOutOff + encLen, 9), List.filled(9, 0xdd));

        final inPlaceBuf = Uint8List(expected.length + 8)
          ..setRange(4, 4 + len, message, 50);
        expect(cipher.encrypt(iv, inPlaceBuf, 4, len, inPlaceBuf, 4), encLen);
        expect(inPlaceBuf.view(4, encLen), expected);
        expect(
          cipher.decrypt(iv, inPlaceBuf, 4, encLen, inPlaceBuf, 4),
          decLen,
        );
        expect(inPlaceBuf.view(4, decLen), inpBuf.view(inpOff, len));
      }
    });

    test('.decrypt() rejects invalid lengths and corrupted PKCS7 padding', () {
      final cipher = AesCbcPkcs7(key);
      final inp = Uint8List(64);
      final out = Uint8List(32);

      for (final invalidLen in [0, 1, 15, 17, 31, 33]) {
        expect(
          () => cipher.decrypt(iv, inp, 0, invalidLen, out, 0),
          throwsA(corruptedPadError),
        );
      }

      final invalidBlocks = [
        Uint8List(16)..fillRange(0, 16, 0),
        Uint8List(16)..fillRange(0, 16, 17),
        Uint8List(16)..fillRange(0, 16, 255),
        Uint8List.fromList([...List.filled(14, 0xaa), 0x01, 0x02]),
        Uint8List.fromList([...List.filled(12, 0x42), 0x04, 0x03, 0x04, 0x04]),
        Uint8List.fromList([0x00, ...List.filled(15, 0x10)]),
      ];

      for (final plainBlock in invalidBlocks) {
        final encryptedBlock = _encryptRawBlock(plainBlock);
        expect(
          () => cipher.decrypt(iv, encryptedBlock, 0, aesBlockSize, out, 0),
          throwsA(corruptedPadError),
        );
      }
    });
  });
}
