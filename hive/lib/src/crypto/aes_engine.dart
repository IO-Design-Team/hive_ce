import 'dart:typed_data';

import 'package:hive_ce/src/crypto/aes_tables.dart';
import 'package:hive_ce/src/util/extensions.dart';

/// The block size of an AES block
const aesBlockSize = 16;

/// The number of encryption rounds
const rounds = 14;

const _m1 = 0x80808080;
const _m2 = 0x7f7f7f7f;
const _m3 = 0x0000001b;

const _mask8 = 0xff;
const _mask16 = 0xffff;
const _mask32 = 0xffffffff;

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
int _subWord(int x) {
  return sBox[x & 255] |
      (sBox[(x >> 8) & 255] << 8) |
      (sBox[(x >> 16) & 255] << 16) |
      sBox[(x >> 24) & 255] << 24;
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
int _invMcol(int x) {
  final f2 = ((x & _m2) << 1) ^ (((x & _m1) >> 7) * _m3);
  final f4 = ((f2 & _m2) << 1) ^ (((f2 & _m1) >> 7) * _m3);
  final f8 = ((f4 & _m2) << 1) ^ (((f4 & _m1) >> 7) * _m3);
  final f9 = x ^ f8;

  final s1 = ((f2 ^ f9) >> 8) | ((((f2 ^ f9) & _mask8) << 24) & _mask32);
  final s2 = ((f4 ^ f9) >> 16) | ((((f4 ^ f9) & _mask16) << 16) & _mask32);
  final s3 = (f9 >> 24) | (((f9 & _mask32) << 8) & _mask32);

  return f2 ^ f4 ^ f8 ^ s1 ^ s2 ^ s3;
}

/// AES implementation (some of the code is from Bouncycastle)
class AesEngine {
  static final _lastInputBlockBuffer = Uint8List(aesBlockSize);

  /// Flatten a 15x4 working key into a contiguous 60-word key schedule.
  static Uint32List flattenWorkingKey(List<Uint32List> workingKey) {
    final flat = Uint32List((rounds + 1) * 4);
    for (var r = 0; r <= rounds; r++) {
      final row = workingKey[r];
      final base = r * 4;
      flat[base] = row[0];
      flat[base + 1] = row[1];
      flat[base + 2] = row[2];
      flat[base + 3] = row[3];
    }
    return flat;
  }

  /// Expand an encryption or decryption key.
  static List<Uint32List> generateWorkingKey(
    List<int> key,
    bool forEncryption,
  ) {
    final w = List.generate(rounds + 1, (_) => Uint32List(4));
    var t0 = key.readUint32(0);
    var t1 = key.readUint32(4);
    var t2 = key.readUint32(8);
    var t3 = key.readUint32(12);
    var t4 = key.readUint32(16);
    var t5 = key.readUint32(20);
    var t6 = key.readUint32(24);
    var t7 = key.readUint32(28);

    w[0][0] = t0;
    w[0][1] = t1;
    w[0][2] = t2;
    w[0][3] = t3;

    w[1][0] = t4;
    w[1][1] = t5;
    w[1][2] = t6;
    w[1][3] = t7;

    int u, rcon = 1;

    for (var i = 2; i < 14; i += 2) {
      u = _subWord((t7 >> 8) | (((t7 & _mask8) << 24) & _mask32)) ^ rcon;
      rcon <<= 1;
      t0 ^= u;
      w[i][0] = t0;
      t1 ^= t0;
      w[i][1] = t1;
      t2 ^= t1;
      w[i][2] = t2;
      t3 ^= t2;
      w[i][3] = t3;
      u = _subWord(t3);
      t4 ^= u;
      w[i + 1][0] = t4;
      t5 ^= t4;
      w[i + 1][1] = t5;
      t6 ^= t5;
      w[i + 1][2] = t6;
      t7 ^= t6;
      w[i + 1][3] = t7;
    }

    u = _subWord((t7 >> 8) | (((t7 & _mask8) << 24) & _mask32)) ^ rcon;
    t0 ^= u;
    w[14][0] = t0;
    t1 ^= t0;
    w[14][1] = t1;
    t2 ^= t1;
    w[14][2] = t2;
    t3 ^= t2;
    w[14][3] = t3;

    if (!forEncryption) {
      for (var j = 1; j < rounds; j++) {
        for (var i = 0; i < 4; i++) {
          w[j][i] = _invMcol(w[j][i]);
        }
      }
    }

    return w;
  }

  /// Encrypt a single block with the [workingKey].
  static void encryptBlock(
    List<Uint32List> workingKey,
    Uint8List inp,
    int inpOff,
    Uint8List out,
    int outOff,
  ) {
    var c0 = inp.readUint32(inpOff) ^ workingKey[0][0];
    var c1 = inp.readUint32(inpOff + 4) ^ workingKey[0][1];
    var c2 = inp.readUint32(inpOff + 8) ^ workingKey[0][2];
    var c3 = inp.readUint32(inpOff + 12) ^ workingKey[0][3];

    int r0, r1, r2, r3;
    var r = 1;
    while (r < rounds - 1) {
      r0 = table0[c0 & 255] ^
          table1[(c1 >>> 8) & 255] ^
          table2[(c2 >>> 16) & 255] ^
          table3[(c3 >>> 24) & 255] ^
          workingKey[r][0];
      r1 = table0[c1 & 255] ^
          table1[(c2 >>> 8) & 255] ^
          table2[(c3 >>> 16) & 255] ^
          table3[(c0 >>> 24) & 255] ^
          workingKey[r][1];
      r2 = table0[c2 & 255] ^
          table1[(c3 >>> 8) & 255] ^
          table2[(c0 >>> 16) & 255] ^
          table3[(c1 >>> 24) & 255] ^
          workingKey[r][2];
      r3 = table0[c3 & 255] ^
          table1[(c0 >>> 8) & 255] ^
          table2[(c1 >>> 16) & 255] ^
          table3[(c2 >>> 24) & 255] ^
          workingKey[r][3];
      r++;
      c0 = table0[r0 & 255] ^
          table1[(r1 >>> 8) & 255] ^
          table2[(r2 >>> 16) & 255] ^
          table3[(r3 >>> 24) & 255] ^
          workingKey[r][0];
      c1 = table0[r1 & 255] ^
          table1[(r2 >>> 8) & 255] ^
          table2[(r3 >>> 16) & 255] ^
          table3[(r0 >>> 24) & 255] ^
          workingKey[r][1];
      c2 = table0[r2 & 255] ^
          table1[(r3 >>> 8) & 255] ^
          table2[(r0 >>> 16) & 255] ^
          table3[(r1 >>> 24) & 255] ^
          workingKey[r][2];
      c3 = table0[r3 & 255] ^
          table1[(r0 >>> 8) & 255] ^
          table2[(r1 >>> 16) & 255] ^
          table3[(r2 >>> 24) & 255] ^
          workingKey[r][3];
      r++;
    }

    r0 = table0[c0 & 255] ^
        table1[(c1 >>> 8) & 255] ^
        table2[(c2 >>> 16) & 255] ^
        table3[(c3 >>> 24) & 255] ^
        workingKey[r][0];
    r1 = table0[c1 & 255] ^
        table1[(c2 >>> 8) & 255] ^
        table2[(c3 >>> 16) & 255] ^
        table3[(c0 >>> 24) & 255] ^
        workingKey[r][1];
    r2 = table0[c2 & 255] ^
        table1[(c3 >>> 8) & 255] ^
        table2[(c0 >>> 16) & 255] ^
        table3[(c1 >>> 24) & 255] ^
        workingKey[r][2];
    r3 = table0[c3 & 255] ^
        table1[(c0 >>> 8) & 255] ^
        table2[(c1 >>> 16) & 255] ^
        table3[(c2 >>> 24) & 255] ^
        workingKey[r][3];
    r++;

    // the final round's table is a simple function of S so we don't use a
    // whole other four tables for it
    c0 = (sBox[r0 & 255] & 255) ^
        (sBox[(r1 >>> 8) & 255] << 8) ^
        (sBox[(r2 >>> 16) & 255] << 16) ^
        (sBox[(r3 >>> 24) & 255] << 24) ^
        workingKey[r][0];
    c1 = (sBox[r1 & 255] & 255) ^
        (sBox[(r2 >>> 8) & 255] << 8) ^
        (sBox[(r3 >>> 16) & 255] << 16) ^
        (sBox[(r0 >>> 24) & 255] << 24) ^
        workingKey[r][1];
    c2 = (sBox[r2 & 255] & 255) ^
        (sBox[(r3 >>> 8) & 255] << 8) ^
        (sBox[(r0 >>> 16) & 255] << 16) ^
        (sBox[(r1 >>> 24) & 255] << 24) ^
        workingKey[r][2];
    c3 = (sBox[r3 & 255] & 255) ^
        (sBox[(r0 >>> 8) & 255] << 8) ^
        (sBox[(r1 >>> 16) & 255] << 16) ^
        (sBox[(r2 >>> 24) & 255] << 24) ^
        workingKey[r][3];

    out.writeUint32(outOff, c0);
    out.writeUint32(outOff + 4, c1);
    out.writeUint32(outOff + 8, c2);
    out.writeUint32(outOff + 12, c3);
  }

  /// Decrypt a single block with [workingKey].
  static void decryptBlock(
    List<Uint32List> workingKey,
    Uint8List inp,
    int inpOff,
    Uint8List out,
    int outOff,
  ) {
    var c0 = inp.readUint32(inpOff) ^ workingKey[rounds][0];
    var c1 = inp.readUint32(inpOff + 4) ^ workingKey[rounds][1];
    var c2 = inp.readUint32(inpOff + 8) ^ workingKey[rounds][2];
    var c3 = inp.readUint32(inpOff + 12) ^ workingKey[rounds][3];

    int r0, r1, r2, r3;
    var r = rounds - 1;
    while (r > 1) {
      r0 = table0Inv[c0 & 255] ^
          table1Inv[(c3 >>> 8) & 255] ^
          table2Inv[(c2 >>> 16) & 255] ^
          table3Inv[(c1 >>> 24) & 255] ^
          workingKey[r][0];
      r1 = table0Inv[c1 & 255] ^
          table1Inv[(c0 >>> 8) & 255] ^
          table2Inv[(c3 >>> 16) & 255] ^
          table3Inv[(c2 >>> 24) & 255] ^
          workingKey[r][1];
      r2 = table0Inv[c2 & 255] ^
          table1Inv[(c1 >>> 8) & 255] ^
          table2Inv[(c0 >>> 16) & 255] ^
          table3Inv[(c3 >>> 24) & 255] ^
          workingKey[r][2];
      r3 = table0Inv[c3 & 255] ^
          table1Inv[(c2 >>> 8) & 255] ^
          table2Inv[(c1 >>> 16) & 255] ^
          table3Inv[(c0 >>> 24) & 255] ^
          workingKey[r][3];
      r--;
      c0 = table0Inv[r0 & 255] ^
          table1Inv[(r3 >>> 8) & 255] ^
          table2Inv[(r2 >>> 16) & 255] ^
          table3Inv[(r1 >>> 24) & 255] ^
          workingKey[r][0];
      c1 = table0Inv[r1 & 255] ^
          table1Inv[(r0 >>> 8) & 255] ^
          table2Inv[(r3 >>> 16) & 255] ^
          table3Inv[(r2 >>> 24) & 255] ^
          workingKey[r][1];
      c2 = table0Inv[r2 & 255] ^
          table1Inv[(r1 >>> 8) & 255] ^
          table2Inv[(r0 >>> 16) & 255] ^
          table3Inv[(r3 >>> 24) & 255] ^
          workingKey[r][2];
      c3 = table0Inv[r3 & 255] ^
          table1Inv[(r2 >>> 8) & 255] ^
          table2Inv[(r1 >>> 16) & 255] ^
          table3Inv[(r0 >>> 24) & 255] ^
          workingKey[r][3];
      r--;
    }

    r0 = table0Inv[c0 & 255] ^
        table1Inv[(c3 >>> 8) & 255] ^
        table2Inv[(c2 >>> 16) & 255] ^
        table3Inv[(c1 >>> 24) & 255] ^
        workingKey[r][0];
    r1 = table0Inv[c1 & 255] ^
        table1Inv[(c0 >>> 8) & 255] ^
        table2Inv[(c3 >>> 16) & 255] ^
        table3Inv[(c2 >>> 24) & 255] ^
        workingKey[r][1];
    r2 = table0Inv[c2 & 255] ^
        table1Inv[(c1 >>> 8) & 255] ^
        table2Inv[(c0 >>> 16) & 255] ^
        table3Inv[(c3 >>> 24) & 255] ^
        workingKey[r][2];
    r3 = table0Inv[c3 & 255] ^
        table1Inv[(c2 >>> 8) & 255] ^
        table2Inv[(c1 >>> 16) & 255] ^
        table3Inv[(c0 >>> 24) & 255] ^
        workingKey[r][3];

    // the final round's table is a simple function of Si so we don't use a
    // whole other four tables for it
    c0 = sBoxInv[r0 & 255] ^
        (sBoxInv[(r3 >>> 8) & 255] << 8) ^
        (sBoxInv[(r2 >>> 16) & 255] << 16) ^
        (sBoxInv[(r1 >>> 24) & 255] << 24) ^
        workingKey[0][0];
    c1 = (sBoxInv[r1 & 255] & 255) ^
        (sBoxInv[(r0 >>> 8) & 255] << 8) ^
        (sBoxInv[(r3 >>> 16) & 255] << 16) ^
        (sBoxInv[(r2 >>> 24) & 255] << 24) ^
        workingKey[0][1];
    c2 = (sBoxInv[r2 & 255] & 255) ^
        (sBoxInv[(r1 >>> 8) & 255] << 8) ^
        (sBoxInv[(r0 >>> 16) & 255] << 16) ^
        (sBoxInv[(r3 >>> 24) & 255] << 24) ^
        workingKey[0][2];
    c3 = (sBoxInv[r3 & 255] & 255) ^
        (sBoxInv[(r2 >>> 8) & 255] << 8) ^
        (sBoxInv[(r1 >>> 16) & 255] << 16) ^
        (sBoxInv[(r0 >>> 24) & 255] << 24) ^
        workingKey[0][3];

    out.writeUint32(outOff, c0);
    out.writeUint32(outOff + 4, c1);
    out.writeUint32(outOff + 8, c2);
    out.writeUint32(outOff + 12, c3);
  }

  /// Encrypt [inp] with PKCS7 padding in CBC mode using [flatKey].
  static int encryptCbc(
    Uint32List flatKey,
    int iv0,
    int iv1,
    int iv2,
    int iv3,
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final k00 = flatKey[0];
    final k01 = flatKey[1];
    final k02 = flatKey[2];
    final k03 = flatKey[3];
    final k52 = flatKey[52];
    final k53 = flatKey[53];
    final k54 = flatKey[54];
    final k55 = flatKey[55];
    final k56 = flatKey[56];
    final k57 = flatKey[57];
    final k58 = flatKey[58];
    final k59 = flatKey[59];

    var v0 = iv0 & _mask32;
    var v1 = iv1 & _mask32;
    var v2 = iv2 & _mask32;
    var v3 = iv3 & _mask32;

    final fullBlocks = inpLength >> 4;
    final remaining = inpLength & 15;
    final padByte = aesBlockSize - remaining;

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
      } else if (remaining == 0) {
        p0 = 0x10101010;
        p1 = 0x10101010;
        p2 = 0x10101010;
        p3 = 0x10101010;
      } else {
        final lastInputBlock = _lastInputBlockBuffer;
        lastInputBlock.setRange(0, remaining, inp, inPos);
        lastInputBlock.fillRange(remaining, aesBlockSize, padByte);
        p0 = lastInputBlock.readUint32(0);
        p1 = lastInputBlock.readUint32(4);
        p2 = lastInputBlock.readUint32(8);
        p3 = lastInputBlock.readUint32(12);
      }

      var c0 = p0 ^ v0 ^ k00;
      var c1 = p1 ^ v1 ^ k01;
      var c2 = p2 ^ v2 ^ k02;
      var c3 = p3 ^ v3 ^ k03;

      int r0, r1, r2, r3;
      var ki = 4;
      while (ki < 52) {
        r0 = table0[c0 & 255] ^
            table1[(c1 >>> 8) & 255] ^
            table2[(c2 >>> 16) & 255] ^
            table3[(c3 >>> 24) & 255] ^
            flatKey[ki];
        r1 = table0[c1 & 255] ^
            table1[(c2 >>> 8) & 255] ^
            table2[(c3 >>> 16) & 255] ^
            table3[(c0 >>> 24) & 255] ^
            flatKey[ki + 1];
        r2 = table0[c2 & 255] ^
            table1[(c3 >>> 8) & 255] ^
            table2[(c0 >>> 16) & 255] ^
            table3[(c1 >>> 24) & 255] ^
            flatKey[ki + 2];
        r3 = table0[c3 & 255] ^
            table1[(c0 >>> 8) & 255] ^
            table2[(c1 >>> 16) & 255] ^
            table3[(c2 >>> 24) & 255] ^
            flatKey[ki + 3];
        c0 = table0[r0 & 255] ^
            table1[(r1 >>> 8) & 255] ^
            table2[(r2 >>> 16) & 255] ^
            table3[(r3 >>> 24) & 255] ^
            flatKey[ki + 4];
        c1 = table0[r1 & 255] ^
            table1[(r2 >>> 8) & 255] ^
            table2[(r3 >>> 16) & 255] ^
            table3[(r0 >>> 24) & 255] ^
            flatKey[ki + 5];
        c2 = table0[r2 & 255] ^
            table1[(r3 >>> 8) & 255] ^
            table2[(r0 >>> 16) & 255] ^
            table3[(r1 >>> 24) & 255] ^
            flatKey[ki + 6];
        c3 = table0[r3 & 255] ^
            table1[(r0 >>> 8) & 255] ^
            table2[(r1 >>> 16) & 255] ^
            table3[(r2 >>> 24) & 255] ^
            flatKey[ki + 7];
        ki += 8;
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

  /// Decrypt [inp] with PKCS7 padding validation in CBC mode using [flatKey].
  static int decryptCbc(
    Uint32List flatKey,
    int iv0,
    int iv1,
    int iv2,
    int iv3,
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    if (inpLength < aesBlockSize || (inpLength & (aesBlockSize - 1)) != 0) {
      throw ArgumentError('Invalid or corrupted pad block');
    }

    final k00 = flatKey[0];
    final k01 = flatKey[1];
    final k02 = flatKey[2];
    final k03 = flatKey[3];
    final k04 = flatKey[4];
    final k05 = flatKey[5];
    final k06 = flatKey[6];
    final k07 = flatKey[7];
    final k56 = flatKey[56];
    final k57 = flatKey[57];
    final k58 = flatKey[58];
    final k59 = flatKey[59];

    var prev0 = iv0 & _mask32;
    var prev1 = iv1 & _mask32;
    var prev2 = iv2 & _mask32;
    var prev3 = iv3 & _mask32;

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
      var ki = 52;
      while (ki > 4) {
        r0 = table0Inv[c0 & 255] ^
            table1Inv[(c3 >>> 8) & 255] ^
            table2Inv[(c2 >>> 16) & 255] ^
            table3Inv[(c1 >>> 24) & 255] ^
            flatKey[ki];
        r1 = table0Inv[c1 & 255] ^
            table1Inv[(c0 >>> 8) & 255] ^
            table2Inv[(c3 >>> 16) & 255] ^
            table3Inv[(c2 >>> 24) & 255] ^
            flatKey[ki + 1];
        r2 = table0Inv[c2 & 255] ^
            table1Inv[(c1 >>> 8) & 255] ^
            table2Inv[(c0 >>> 16) & 255] ^
            table3Inv[(c3 >>> 24) & 255] ^
            flatKey[ki + 2];
        r3 = table0Inv[c3 & 255] ^
            table1Inv[(c2 >>> 8) & 255] ^
            table2Inv[(c1 >>> 16) & 255] ^
            table3Inv[(c0 >>> 24) & 255] ^
            flatKey[ki + 3];
        c0 = table0Inv[r0 & 255] ^
            table1Inv[(r3 >>> 8) & 255] ^
            table2Inv[(r2 >>> 16) & 255] ^
            table3Inv[(r1 >>> 24) & 255] ^
            flatKey[ki - 4];
        c1 = table0Inv[r1 & 255] ^
            table1Inv[(r0 >>> 8) & 255] ^
            table2Inv[(r3 >>> 16) & 255] ^
            table3Inv[(r2 >>> 24) & 255] ^
            flatKey[ki - 3];
        c2 = table0Inv[r2 & 255] ^
            table1Inv[(r1 >>> 8) & 255] ^
            table2Inv[(r0 >>> 16) & 255] ^
            table3Inv[(r3 >>> 24) & 255] ^
            flatKey[ki - 2];
        c3 = table0Inv[r3 & 255] ^
            table1Inv[(r2 >>> 8) & 255] ^
            table2Inv[(r1 >>> 16) & 255] ^
            table3Inv[(r0 >>> 24) & 255] ^
            flatKey[ki - 1];
        ki -= 8;
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

    return (outPos - outOff) - lastDecryptedByte;
  }
}
