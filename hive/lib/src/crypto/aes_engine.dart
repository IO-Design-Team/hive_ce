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
  /// Expand an encryption or decryption key into a flat 60-word key schedule.
  static Uint32List generateWorkingKey(
    List<int> key,
    bool forEncryption,
  ) {
    final w = Uint32List((rounds + 1) * 4);
    var t0 = key.readUint32(0);
    var t1 = key.readUint32(4);
    var t2 = key.readUint32(8);
    var t3 = key.readUint32(12);
    var t4 = key.readUint32(16);
    var t5 = key.readUint32(20);
    var t6 = key.readUint32(24);
    var t7 = key.readUint32(28);

    w[0] = t0;
    w[1] = t1;
    w[2] = t2;
    w[3] = t3;

    w[4] = t4;
    w[5] = t5;
    w[6] = t6;
    w[7] = t7;

    int u, rcon = 1;

    for (var i = 8; i < 56; i += 8) {
      u = _subWord((t7 >> 8) | (((t7 & _mask8) << 24) & _mask32)) ^ rcon;
      rcon <<= 1;
      t0 ^= u;
      w[i] = t0;
      t1 ^= t0;
      w[i + 1] = t1;
      t2 ^= t1;
      w[i + 2] = t2;
      t3 ^= t2;
      w[i + 3] = t3;
      u = _subWord(t3);
      t4 ^= u;
      w[i + 4] = t4;
      t5 ^= t4;
      w[i + 5] = t5;
      t6 ^= t5;
      w[i + 6] = t6;
      t7 ^= t6;
      w[i + 7] = t7;
    }

    u = _subWord((t7 >> 8) | (((t7 & _mask8) << 24) & _mask32)) ^ rcon;
    t0 ^= u;
    w[56] = t0;
    t1 ^= t0;
    w[57] = t1;
    t2 ^= t1;
    w[58] = t2;
    t3 ^= t2;
    w[59] = t3;

    if (!forEncryption) {
      for (var i = 4; i < rounds * 4; i++) {
        w[i] = _invMcol(w[i]);
      }
    }

    return w;
  }
}
