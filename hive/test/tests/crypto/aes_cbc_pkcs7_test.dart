import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_cbc_pkcs7.dart';
import 'package:hive_ce/src/crypto/aes_engine.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

import 'message.dart';

PaddedBlockCipherImpl getCipher({Uint8List? customIv}) {
  final pcCipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  pcCipher.init(
    true,
    PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(key), customIv ?? iv),
      null,
    ),
  );
  return pcCipher;
}

Uint8List _expectedCbcPkcs7(Uint8List input, {Uint8List? customIv}) {
  if (input.isNotEmpty) {
    return getCipher(customIv: customIv).process(input);
  }
  final ivBytes = customIv ?? iv;
  final block = Uint8List(aesBlockSize);
  for (var i = 0; i < aesBlockSize; i++) {
    block[i] = aesBlockSize ^ ivBytes[i];
  }
  final out = Uint8List(aesBlockSize);
  (AESEngine()..init(true, KeyParameter(key))).processBlock(block, 0, out, 0);
  return out;
}

Uint8List _encryptRawBlock(Uint8List plainBlock, Uint8List customIv) {
  final cipher = getCipher(customIv: customIv);
  // Encrypts plainBlock + full PKCS7 block; first 16 bytes are CBC(plainBlock).
  final full = cipher.process(plainBlock);
  return Uint8List.sublistView(full, 0, aesBlockSize);
}

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

    test('supports non-zero inpOff, outOff, and ivOff', () {
      final cipher = AesCbcPkcs7(key);
      final ivStorage = Uint8List(30)..fillRange(0, 30, 0x11);
      ivStorage.setRange(7, 7 + 16, iv);

      for (final len in <int>[0, 1, 15, 16, 17, 32, 63, 64, 257]) {
        const inpOff = 13;
        const outOff = 19;
        final inpBuf = Uint8List(inpOff + len + 5)
          ..fillRange(0, inpOff + len + 5, 0xee);
        inpBuf.setRange(inpOff, inpOff + len, message, 50);

        final expected = _expectedCbcPkcs7(
          Uint8List.sublistView(inpBuf, inpOff, inpOff + len),
        );
        final outBuf = Uint8List(outOff + expected.length + 11)
          ..fillRange(0, outOff + expected.length + 11, 0xcc);

        final encLen = cipher.encrypt(
          ivStorage,
          inpBuf,
          inpOff,
          len,
          outBuf,
          outOff,
          ivOff: 7,
        );
        expect(encLen, expected.length);
        expect(outBuf.sublist(outOff, outOff + encLen), expected);
        expect(outBuf.sublist(0, outOff), List.filled(outOff, 0xcc));
        expect(outBuf.sublist(outOff + encLen), List.filled(11, 0xcc));

        const decOutOff = 5;
        final decBuf = Uint8List(decOutOff + encLen + 9)
          ..fillRange(0, decOutOff + encLen + 9, 0xdd);
        final decLen = cipher.decrypt(
          ivStorage,
          outBuf,
          outOff,
          encLen,
          decBuf,
          decOutOff,
          ivOff: 7,
        );
        expect(decLen, len);
        expect(
          decBuf.sublist(decOutOff, decOutOff + decLen),
          inpBuf.sublist(inpOff, inpOff + len),
        );
        expect(decBuf.sublist(0, decOutOff), List.filled(decOutOff, 0xdd));
        expect(decBuf.sublist(decOutOff + encLen), List.filled(9, 0xdd));
      }
    });

    test('supports in-place encryption and decryption', () {
      final cipher = AesCbcPkcs7(key);
      for (final len in <int>[0, 1, 15, 16, 31, 32, 64, 199]) {
        final paddedLen = ((len ~/ aesBlockSize) + 1) * aesBlockSize;
        final buf = Uint8List(paddedLen + 8);
        buf.setRange(4, 4 + len, message, 100);

        final expected = _expectedCbcPkcs7(
          Uint8List.sublistView(message, 100, 100 + len),
        );

        final encLen = cipher.encrypt(iv, buf, 4, len, buf, 4);
        expect(encLen, expected.length);
        expect(buf.sublist(4, 4 + encLen), expected);

        final decLen = cipher.decrypt(iv, buf, 4, encLen, buf, 4);
        expect(decLen, len);
        expect(buf.sublist(4, 4 + decLen), message.sublist(100, 100 + len));
      }
    });

    test('.decrypt() throws on invalid ciphertext lengths', () {
      final cipher = AesCbcPkcs7(key);
      final inp = Uint8List(64);
      final out = Uint8List(64);

      for (final invalidLen in <int>[0, 1, 15, 17, 31, 33]) {
        expect(
          () => cipher.decrypt(iv, inp, 0, invalidLen, out, 0),
          throwsA(corruptedPadError),
        );
      }
    });

    test('.decrypt() throws on invalid or corrupted PKCS7 padding', () {
      final cipher = AesCbcPkcs7(key);
      final out = Uint8List(32);

      final invalidBlocks = <Uint8List>[
        // Pad byte = 0
        Uint8List(16)..fillRange(0, 16, 0),
        // Pad byte = 17 (> block size)
        Uint8List(16)..fillRange(0, 16, 17),
        // Pad byte = 255
        Uint8List(16)..fillRange(0, 16, 255),
        // Claims pad = 2, second-to-last byte is 1
        Uint8List.fromList(<int>[...List.filled(14, 0xaa), 0x01, 0x02]),
        // Claims pad = 4, one padding byte corrupted
        Uint8List.fromList(<int>[
          ...List.filled(12, 0x42),
          0x04,
          0x03,
          0x04,
          0x04,
        ]),
      ];

      for (final plainBlock in invalidBlocks) {
        final encryptedBlock = _encryptRawBlock(plainBlock, iv);
        expect(
          () => cipher.decrypt(iv, encryptedBlock, 0, aesBlockSize, out, 0),
          throwsA(corruptedPadError),
        );
      }
    });
  });
}
