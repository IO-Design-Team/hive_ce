import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_engine.dart';
import 'package:hive_ce/src/crypto/aes_tables.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:meta/meta.dart';

/// AES CBC implementation with PKCS7 padding
@immutable
class AesCbcPkcs7 {
  final Uint8List _keyBytes;

  late final Uint32List _encryptionKey =
      AesEngine.generateWorkingKey(_keyBytes, true);
  late final Uint32List _decryptionKey =
      AesEngine.generateWorkingKey(_keyBytes, false);

  /// Not part of public API
  AesCbcPkcs7(this._keyBytes);

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  static int _readPaddedUint32(
    Uint8List inp,
    int inPos,
    int remaining,
    int offset,
    int padByte,
    int padWord,
  ) {
    final rem = remaining - offset;
    if (rem >= 4) return inp.readUint32(inPos + offset);
    if (rem <= 0) return padWord;
    final b0 = inp[inPos + offset];
    final b1 = rem > 1 ? inp[inPos + offset + 1] : padByte;
    final b2 = rem > 2 ? inp[inPos + offset + 2] : padByte;
    return b0 | (b1 << 8) | (b2 << 16) | (padByte << 24);
  }

  /// Not part of public API
  int encrypt(
    Uint8List iv,
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final key = _encryptionKey;
    final k00 = key[0];
    final k01 = key[1];
    final k02 = key[2];
    final k03 = key[3];
    final k52 = key[52];
    final k53 = key[53];
    final k54 = key[54];
    final k55 = key[55];
    final k56 = key[56];
    final k57 = key[57];
    final k58 = key[58];
    final k59 = key[59];

    var v0 = iv.readUint32(0);
    var v1 = iv.readUint32(4);
    var v2 = iv.readUint32(8);
    var v3 = iv.readUint32(12);

    final fullBlocks = inpLength >> 4;
    var inPos = inpOff;
    var outPos = outOff;

    for (var block = 0; block <= fullBlocks; block++) {
      int p0, p1, p2, p3;
      if (block < fullBlocks) {
        p0 = inp.readUint32(inPos);
        p1 = inp.readUint32(inPos + 4);
        p2 = inp.readUint32(inPos + 8);
        p3 = inp.readUint32(inPos + 12);
        inPos += aesBlockSize;
      } else {
        final remaining = inpLength & 15;
        final padByte = aesBlockSize - remaining;
        final padWord = padByte * 0x01010101;
        p0 = _readPaddedUint32(inp, inPos, remaining, 0, padByte, padWord);
        p1 = _readPaddedUint32(inp, inPos, remaining, 4, padByte, padWord);
        p2 = _readPaddedUint32(inp, inPos, remaining, 8, padByte, padWord);
        p3 = _readPaddedUint32(inp, inPos, remaining, 12, padByte, padWord);
      }

      var c0 = p0 ^ v0 ^ k00;
      var c1 = p1 ^ v1 ^ k01;
      var c2 = p2 ^ v2 ^ k02;
      var c3 = p3 ^ v3 ^ k03;

      int r0, r1, r2, r3;
      for (var ki = 4; ki < 52; ki += 8) {
        r0 = table0[c0 & 255] ^
            table1[(c1 >>> 8) & 255] ^
            table2[(c2 >>> 16) & 255] ^
            table3[(c3 >>> 24) & 255] ^
            key[ki];
        r1 = table0[c1 & 255] ^
            table1[(c2 >>> 8) & 255] ^
            table2[(c3 >>> 16) & 255] ^
            table3[(c0 >>> 24) & 255] ^
            key[ki + 1];
        r2 = table0[c2 & 255] ^
            table1[(c3 >>> 8) & 255] ^
            table2[(c0 >>> 16) & 255] ^
            table3[(c1 >>> 24) & 255] ^
            key[ki + 2];
        r3 = table0[c3 & 255] ^
            table1[(c0 >>> 8) & 255] ^
            table2[(c1 >>> 16) & 255] ^
            table3[(c2 >>> 24) & 255] ^
            key[ki + 3];
        c0 = table0[r0 & 255] ^
            table1[(r1 >>> 8) & 255] ^
            table2[(r2 >>> 16) & 255] ^
            table3[(r3 >>> 24) & 255] ^
            key[ki + 4];
        c1 = table0[r1 & 255] ^
            table1[(r2 >>> 8) & 255] ^
            table2[(r3 >>> 16) & 255] ^
            table3[(r0 >>> 24) & 255] ^
            key[ki + 5];
        c2 = table0[r2 & 255] ^
            table1[(r3 >>> 8) & 255] ^
            table2[(r0 >>> 16) & 255] ^
            table3[(r1 >>> 24) & 255] ^
            key[ki + 6];
        c3 = table0[r3 & 255] ^
            table1[(r0 >>> 8) & 255] ^
            table2[(r1 >>> 16) & 255] ^
            table3[(r2 >>> 24) & 255] ^
            key[ki + 7];
      }

      r0 = table0[c0 & 255] ^
          table1[(c1 >>> 8) & 255] ^
          table2[(c2 >>> 16) & 255] ^
          table3[(c3 >>> 24) & 255] ^
          k52;
      r1 = table0[c1 & 255] ^
          table1[(c2 >>> 8) & 255] ^
          table2[(c3 >>> 16) & 255] ^
          table3[(c0 >>> 24) & 255] ^
          k53;
      r2 = table0[c2 & 255] ^
          table1[(c3 >>> 8) & 255] ^
          table2[(c0 >>> 16) & 255] ^
          table3[(c1 >>> 24) & 255] ^
          k54;
      r3 = table0[c3 & 255] ^
          table1[(c0 >>> 8) & 255] ^
          table2[(c1 >>> 16) & 255] ^
          table3[(c2 >>> 24) & 255] ^
          k55;

      v0 = sBox[r0 & 255] ^
          (sBox[(r1 >>> 8) & 255] << 8) ^
          (sBox[(r2 >>> 16) & 255] << 16) ^
          (sBox[(r3 >>> 24) & 255] << 24) ^
          k56;
      v1 = sBox[r1 & 255] ^
          (sBox[(r2 >>> 8) & 255] << 8) ^
          (sBox[(r3 >>> 16) & 255] << 16) ^
          (sBox[(r0 >>> 24) & 255] << 24) ^
          k57;
      v2 = sBox[r2 & 255] ^
          (sBox[(r3 >>> 8) & 255] << 8) ^
          (sBox[(r0 >>> 16) & 255] << 16) ^
          (sBox[(r1 >>> 24) & 255] << 24) ^
          k58;
      v3 = sBox[r3 & 255] ^
          (sBox[(r0 >>> 8) & 255] << 8) ^
          (sBox[(r1 >>> 16) & 255] << 16) ^
          (sBox[(r2 >>> 24) & 255] << 24) ^
          k59;

      out.writeUint32(outPos, v0);
      out.writeUint32(outPos + 4, v1);
      out.writeUint32(outPos + 8, v2);
      out.writeUint32(outPos + 12, v3);
      outPos += aesBlockSize;
    }

    return outPos - outOff;
  }

  /// Not part of public API
  int decrypt(
    Uint8List iv,
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    if (inpLength < aesBlockSize || (inpLength & (aesBlockSize - 1)) != 0) {
      throw ArgumentError('Invalid or corrupted pad block');
    }

    final key = _decryptionKey;
    final k00 = key[0];
    final k01 = key[1];
    final k02 = key[2];
    final k03 = key[3];
    final k04 = key[4];
    final k05 = key[5];
    final k06 = key[6];
    final k07 = key[7];
    final k56 = key[56];
    final k57 = key[57];
    final k58 = key[58];
    final k59 = key[59];

    var prev0 = iv.readUint32(0);
    var prev1 = iv.readUint32(4);
    var prev2 = iv.readUint32(8);
    var prev3 = iv.readUint32(12);

    var inPos = inpOff;
    final inEnd = inpOff + inpLength;
    var outPos = outOff;

    while (inPos < inEnd) {
      final in0 = inp.readUint32(inPos);
      final in1 = inp.readUint32(inPos + 4);
      final in2 = inp.readUint32(inPos + 8);
      final in3 = inp.readUint32(inPos + 12);
      inPos += aesBlockSize;

      var c0 = in0 ^ k56;
      var c1 = in1 ^ k57;
      var c2 = in2 ^ k58;
      var c3 = in3 ^ k59;

      int r0, r1, r2, r3;
      for (var ki = 52; ki > 4; ki -= 8) {
        r0 = table0Inv[c0 & 255] ^
            table1Inv[(c3 >>> 8) & 255] ^
            table2Inv[(c2 >>> 16) & 255] ^
            table3Inv[(c1 >>> 24) & 255] ^
            key[ki];
        r1 = table0Inv[c1 & 255] ^
            table1Inv[(c0 >>> 8) & 255] ^
            table2Inv[(c3 >>> 16) & 255] ^
            table3Inv[(c2 >>> 24) & 255] ^
            key[ki + 1];
        r2 = table0Inv[c2 & 255] ^
            table1Inv[(c1 >>> 8) & 255] ^
            table2Inv[(c0 >>> 16) & 255] ^
            table3Inv[(c3 >>> 24) & 255] ^
            key[ki + 2];
        r3 = table0Inv[c3 & 255] ^
            table1Inv[(c2 >>> 8) & 255] ^
            table2Inv[(c1 >>> 16) & 255] ^
            table3Inv[(c0 >>> 24) & 255] ^
            key[ki + 3];
        c0 = table0Inv[r0 & 255] ^
            table1Inv[(r3 >>> 8) & 255] ^
            table2Inv[(r2 >>> 16) & 255] ^
            table3Inv[(r1 >>> 24) & 255] ^
            key[ki - 4];
        c1 = table0Inv[r1 & 255] ^
            table1Inv[(r0 >>> 8) & 255] ^
            table2Inv[(r3 >>> 16) & 255] ^
            table3Inv[(r2 >>> 24) & 255] ^
            key[ki - 3];
        c2 = table0Inv[r2 & 255] ^
            table1Inv[(r1 >>> 8) & 255] ^
            table2Inv[(r0 >>> 16) & 255] ^
            table3Inv[(r3 >>> 24) & 255] ^
            key[ki - 2];
        c3 = table0Inv[r3 & 255] ^
            table1Inv[(r2 >>> 8) & 255] ^
            table2Inv[(r1 >>> 16) & 255] ^
            table3Inv[(r0 >>> 24) & 255] ^
            key[ki - 1];
      }

      r0 = table0Inv[c0 & 255] ^
          table1Inv[(c3 >>> 8) & 255] ^
          table2Inv[(c2 >>> 16) & 255] ^
          table3Inv[(c1 >>> 24) & 255] ^
          k04;
      r1 = table0Inv[c1 & 255] ^
          table1Inv[(c0 >>> 8) & 255] ^
          table2Inv[(c3 >>> 16) & 255] ^
          table3Inv[(c2 >>> 24) & 255] ^
          k05;
      r2 = table0Inv[c2 & 255] ^
          table1Inv[(c1 >>> 8) & 255] ^
          table2Inv[(c0 >>> 16) & 255] ^
          table3Inv[(c3 >>> 24) & 255] ^
          k06;
      r3 = table0Inv[c3 & 255] ^
          table1Inv[(c2 >>> 8) & 255] ^
          table2Inv[(c1 >>> 16) & 255] ^
          table3Inv[(c0 >>> 24) & 255] ^
          k07;

      final p0 = sBoxInv[r0 & 255] ^
          (sBoxInv[(r3 >>> 8) & 255] << 8) ^
          (sBoxInv[(r2 >>> 16) & 255] << 16) ^
          (sBoxInv[(r1 >>> 24) & 255] << 24) ^
          k00 ^
          prev0;
      final p1 = sBoxInv[r1 & 255] ^
          (sBoxInv[(r0 >>> 8) & 255] << 8) ^
          (sBoxInv[(r3 >>> 16) & 255] << 16) ^
          (sBoxInv[(r2 >>> 24) & 255] << 24) ^
          k01 ^
          prev1;
      final p2 = sBoxInv[r2 & 255] ^
          (sBoxInv[(r1 >>> 8) & 255] << 8) ^
          (sBoxInv[(r0 >>> 16) & 255] << 16) ^
          (sBoxInv[(r3 >>> 24) & 255] << 24) ^
          k02 ^
          prev2;
      final p3 = sBoxInv[r3 & 255] ^
          (sBoxInv[(r2 >>> 8) & 255] << 8) ^
          (sBoxInv[(r1 >>> 16) & 255] << 16) ^
          (sBoxInv[(r0 >>> 24) & 255] << 24) ^
          k03 ^
          prev3;

      out.writeUint32(outPos, p0);
      out.writeUint32(outPos + 4, p1);
      out.writeUint32(outPos + 8, p2);
      out.writeUint32(outPos + 12, p3);
      outPos += aesBlockSize;

      prev0 = in0;
      prev1 = in1;
      prev2 = in2;
      prev3 = in3;
    }

    final lastDecryptedByte = out[outPos - 1];
    if (lastDecryptedByte < 1 || lastDecryptedByte > aesBlockSize) {
      throw ArgumentError('Invalid or corrupted pad block');
    }
    for (var i = 1; i < lastDecryptedByte; i++) {
      if (out[outPos - i - 1] != lastDecryptedByte) {
        throw ArgumentError('Invalid or corrupted pad block');
      }
    }

    return inpLength - lastDecryptedByte;
  }
}
