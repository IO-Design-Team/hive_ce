import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_engine.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:test/test.dart';

import 'message.dart';

Uint8List _referenceCbcEncrypt(
  List<Uint32List> workingKey,
  Uint8List ivBytes,
  Uint8List inp,
  int inpOff,
  int inpLength,
) {
  final blockCount = (inpLength ~/ aesBlockSize) + 1;
  final out = Uint8List(blockCount * aesBlockSize);
  final cbc = Uint8List.fromList(ivBytes);
  final remaining = inpLength % aesBlockSize;
  var offset = 0;

  for (var b = 0; b < blockCount - 1; b++) {
    for (var i = 0; i < aesBlockSize; i++) {
      cbc[i] ^= inp[inpOff + offset + i];
    }
    AesEngine.encryptBlock(workingKey, cbc, 0, out, offset);
    cbc.setRange(0, aesBlockSize, out, offset);
    offset += aesBlockSize;
  }

  final lastBlock = Uint8List(aesBlockSize);
  lastBlock.setRange(0, remaining, inp, inpOff + offset);
  lastBlock.fillRange(remaining, aesBlockSize, aesBlockSize - remaining);
  for (var i = 0; i < aesBlockSize; i++) {
    cbc[i] ^= lastBlock[i];
  }
  AesEngine.encryptBlock(workingKey, cbc, 0, out, offset);
  return out;
}

Uint8List _referenceCbcDecrypt(
  List<Uint32List> workingKey,
  Uint8List ivBytes,
  Uint8List inp,
  int inpOff,
  int inpLength,
) {
  final out = Uint8List(inpLength);
  var offset = 0;
  AesEngine.decryptBlock(workingKey, inp, inpOff, out, 0);
  for (var i = 0; i < aesBlockSize; i++) {
    out[i] ^= ivBytes[i];
  }
  offset += aesBlockSize;
  while (offset < inpLength) {
    AesEngine.decryptBlock(workingKey, inp, inpOff + offset, out, offset);
    for (var i = 0; i < aesBlockSize; i++) {
      out[offset + i] ^= inp[inpOff + offset - aesBlockSize + i];
    }
    offset += aesBlockSize;
  }
  final pad = out[inpLength - 1];
  return Uint8List.sublistView(out, 0, inpLength - pad);
}

Uint8List _encryptRawSingleBlock(Uint8List plainBlock, Uint8List ivBytes) {
  final xored = Uint8List(aesBlockSize);
  for (var i = 0; i < aesBlockSize; i++) {
    xored[i] = plainBlock[i] ^ ivBytes[i];
  }
  final out = Uint8List(aesBlockSize);
  AesEngine.encryptBlock(encryptionKey, xored, 0, out, 0);
  return out;
}

void main() {
  final corruptedPadError = isA<ArgumentError>().having(
    (e) => e.message,
    'message',
    'Invalid or corrupted pad block',
  );

  group('AesEngine', () {
    test('.generateWorkingKey()', () {
      expect(AesEngine.generateWorkingKey(key, true), encryptionKey);
      expect(AesEngine.generateWorkingKey(key, false), decryptionKey);
    });

    test('.flattenWorkingKey()', () {
      for (final workingKey in <List<Uint32List>>[
        encryptionKey,
        decryptionKey,
      ]) {
        final flat = AesEngine.flattenWorkingKey(workingKey);
        expect(flat.length, (rounds + 1) * 4);
        for (var r = 0; r <= rounds; r++) {
          for (var i = 0; i < 4; i++) {
            expect(flat[r * 4 + i], workingKey[r][i]);
          }
        }
      }
    });

    test('.encryptBlock()', () {
      final out = Uint8List(message.length);

      final pcEngine = AESEngine();
      final outPc = Uint8List(message.length);

      for (var i = 0; i < message.length; i += aesBlockSize) {
        AesEngine.encryptBlock(encryptionKey, message, i, out, i);
        pcEngine.init(true, KeyParameter(key));
        pcEngine.processBlock(message, i, outPc, i);
      }
      expect(out, outPc);
    });

    test('.decryptBlock()', () {
      final out = Uint8List(message.length);

      final pcEngine = AESEngine();
      final encrypted = Uint8List(message.length);

      for (var i = 0; i < message.length; i += aesBlockSize) {
        AesEngine.decryptBlock(encryptionKey, message, i, out, i);
        pcEngine.init(true, KeyParameter(key));
        pcEngine.processBlock(message, i, encrypted, i);
      }

      for (var i = 0; i < encrypted.length; i += aesBlockSize) {
        AesEngine.decryptBlock(decryptionKey, encrypted, i, out, i);
      }
      expect(out, message);
    });

    test('.encryptCbc() and .decryptCbc() match block-level CBC', () {
      final flatEnc = AesEngine.flattenWorkingKey(encryptionKey);
      final flatDec = AesEngine.flattenWorkingKey(decryptionKey);
      final iv0 = iv.readUint32(0);
      final iv1 = iv.readUint32(4);
      final iv2 = iv.readUint32(8);
      final iv3 = iv.readUint32(12);

      final lengths = <int>[
        for (var len = 0; len <= 64; len++) len,
        message.length - 13,
      ];
      final offsets = <int>[0, 1, 7, 16];

      for (final len in lengths) {
        for (final inpOff in offsets) {
          if (inpOff + len > message.length) continue;
          const outOff = 11;
          final expectedEnc = _referenceCbcEncrypt(
            encryptionKey,
            iv,
            message,
            inpOff,
            len,
          );
          final actualEncBuf = Uint8List(outOff + expectedEnc.length + 13)
            ..fillRange(0, outOff + expectedEnc.length + 13, 0xaa);

          final encLen = AesEngine.encryptCbc(
            flatEnc,
            iv0,
            iv1,
            iv2,
            iv3,
            message,
            inpOff,
            len,
            actualEncBuf,
            outOff,
          );
          expect(encLen, expectedEnc.length);
          expect(actualEncBuf.sublist(outOff, outOff + encLen), expectedEnc);
          expect(actualEncBuf.sublist(0, outOff), List.filled(outOff, 0xaa));
          expect(actualEncBuf.sublist(outOff + encLen), List.filled(13, 0xaa));

          final expectedDec = _referenceCbcDecrypt(
            decryptionKey,
            iv,
            actualEncBuf,
            outOff,
            encLen,
          );
          const decOutOff = 9;
          final actualDecBuf = Uint8List(decOutOff + encLen + 7)
            ..fillRange(0, decOutOff + encLen + 7, 0x55);

          final decLen = AesEngine.decryptCbc(
            flatDec,
            iv0,
            iv1,
            iv2,
            iv3,
            actualEncBuf,
            outOff,
            encLen,
            actualDecBuf,
            decOutOff,
          );
          expect(decLen, len);
          expect(
            actualDecBuf.sublist(decOutOff, decOutOff + decLen),
            expectedDec,
          );
          expect(
            actualDecBuf.sublist(decOutOff, decOutOff + decLen),
            message.sublist(inpOff, inpOff + len),
          );
          expect(
            actualDecBuf.sublist(0, decOutOff),
            List.filled(decOutOff, 0x55),
          );
          expect(
            actualDecBuf.sublist(decOutOff + encLen),
            List.filled(7, 0x55),
          );
        }
      }
    });

    test('.decryptCbc() rejects invalid lengths and corrupted PKCS7 padding',
        () {
      final flatDec = AesEngine.flattenWorkingKey(decryptionKey);
      final iv0 = iv.readUint32(0);
      final iv1 = iv.readUint32(4);
      final iv2 = iv.readUint32(8);
      final iv3 = iv.readUint32(12);
      final inp = Uint8List(64);
      final out = Uint8List(64);

      for (final invalidLen in <int>[0, 1, 15, 17, 31, 33]) {
        expect(
          () => AesEngine.decryptCbc(
            flatDec,
            iv0,
            iv1,
            iv2,
            iv3,
            inp,
            0,
            invalidLen,
            out,
            0,
          ),
          throwsA(corruptedPadError),
        );
      }

      final invalidBlocks = <Uint8List>[
        Uint8List(16)..fillRange(0, 16, 0),
        Uint8List(16)..fillRange(0, 16, 17),
        Uint8List(16)..fillRange(0, 16, 255),
        Uint8List.fromList(<int>[...List.filled(14, 0xaa), 0x01, 0x02]),
        Uint8List.fromList(<int>[
          ...List.filled(12, 0x42),
          0x04,
          0x03,
          0x04,
          0x04,
        ]),
        Uint8List.fromList(<int>[0x00, ...List.filled(15, 0x10)]),
      ];

      for (final plainBlock in invalidBlocks) {
        final encryptedBlock = _encryptRawSingleBlock(plainBlock, iv);
        expect(
          () => AesEngine.decryptCbc(
            flatDec,
            iv0,
            iv1,
            iv2,
            iv3,
            encryptedBlock,
            0,
            aesBlockSize,
            out,
            0,
          ),
          throwsA(corruptedPadError),
        );
      }
    });
  });
}
