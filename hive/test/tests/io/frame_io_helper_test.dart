@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/io/frame_io_helper.dart';
import 'package:test/test.dart';

import '../common.dart';
import '../frames.dart';

import 'package:meta/meta.dart';

Uint8List _getBytes(List<Uint8List> list) {
  final builder = BytesBuilder();
  for (final b in list) {
    builder.add(b);
  }
  return builder.toBytes();
}

@immutable
class _FrameIoHelperTest extends FrameIoHelper {
  final Uint8List bytes;

  _FrameIoHelperTest(this.bytes);

  @override
  Future<RandomAccessFile> openFile(String path) {
    return getTempRaf(bytes);
  }

  @override
  Future<Uint8List> readFile(String path) async {
    return bytes;
  }
}

void main() {
  group('FrameIoHelper', () {
    group('.keysFromFile()', () {
      test('frame', () async {
        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(_getBytes(frameBytes));
        final recoveryOffset = await ioHelper.keysFromFile(
          'null',
          keystore,
          null,
          null,
        );
        expect(recoveryOffset, -1);

        final testKeystore = Keystore.debug(
          frames: lazyFrames(framesSetLengthOffset(testFrames, frameBytes)),
        );

        expectFrames(keystore.frames, testKeystore.frames);
      });

      test('encrypted', () async {
        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(_getBytes(frameBytesEncrypted));
        final recoveryOffset = await ioHelper.keysFromFile(
          'null',
          keystore,
          testCipher,
          null,
        );
        expect(recoveryOffset, -1);

        final testKeystore = Keystore.debug(
          frames: lazyFrames(
            framesSetLengthOffset(testFrames, frameBytesEncrypted),
          ),
        );

        expectFrames(keystore.frames, testKeystore.frames);
      });

      test('returns offset if problem occurs', () {});
    });

    group('.allFromFile()', () {
      test('frame', () async {
        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(_getBytes(frameBytes));
        final recoveryOffset = await ioHelper.framesFromFile(
          'null',
          keystore,
          testRegistry,
          null,
          null,
        );
        expect(recoveryOffset, -1);

        final testKeystore = Keystore.debug(
          frames: framesSetLengthOffset(testFrames, frameBytes),
        );

        expectFrames(keystore.frames, testKeystore.frames);
      });

      test('encrypted', () async {
        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(_getBytes(frameBytesEncrypted));
        final recoveryOffset = await ioHelper.framesFromFile(
          'null',
          keystore,
          testRegistry,
          testCipher,
          null,
        );
        expect(recoveryOffset, -1);

        final testKeystore = Keystore.debug(
          frames: framesSetLengthOffset(testFrames, frameBytesEncrypted),
        );

        expectFrames(keystore.frames, testKeystore.frames);
      });

      test('returns offset if problem occurs', () {});
    });

    group('.keysFromRaf()', () {
      test('frame', () async {
        final bytes = _getBytes(frameBytes);
        final keystore = Keystore.debug();
        final raf = await getTempRaf(bytes);
        try {
          await raf.setPosition(5);
          final recoveryOffset = await FrameIoHelper().keysFromRaf(
            raf,
            bytes.length,
            keystore,
            null,
            null,
          );
          expect(recoveryOffset, -1);

          final testKeystore = Keystore.debug(
            frames: lazyFrames(framesSetLengthOffset(testFrames, frameBytes)),
          );
          expectFrames(keystore.frames, testKeystore.frames);
          expect(await raf.length(), bytes.length);
        } finally {
          await raf.close();
        }
      });

      test('encrypted', () async {
        final bytes = _getBytes(frameBytesEncrypted);
        final keystore = Keystore.debug();
        final raf = await getTempRaf(bytes);
        try {
          final recoveryOffset = await FrameIoHelper().keysFromRaf(
            raf,
            bytes.length,
            keystore,
            testCipher,
            null,
          );
          expect(recoveryOffset, -1);

          final testKeystore = Keystore.debug(
            frames: lazyFrames(
              framesSetLengthOffset(testFrames, frameBytesEncrypted),
            ),
          );
          expectFrames(keystore.frames, testKeystore.frames);
          expect(await raf.length(), bytes.length);
        } finally {
          await raf.close();
        }
      });

      test('empty file returns -1 and leaves raf open', () async {
        final keystore = Keystore.debug();
        final raf = await getTempRaf(const []);
        try {
          final recoveryOffset = await FrameIoHelper().keysFromRaf(
            raf,
            0,
            keystore,
            null,
            null,
          );
          expect(recoveryOffset, -1);
          expect(keystore.frames, isEmpty);
          expect(await raf.length(), 0);
        } finally {
          await raf.close();
        }
      });
    });

    group('.framesFromRaf()', () {
      test('frame', () async {
        final bytes = _getBytes(frameBytes);
        final keystore = Keystore.debug();
        final raf = await getTempRaf(bytes);
        try {
          await raf.setPosition(5);
          final recoveryOffset = await FrameIoHelper().framesFromRaf(
            raf,
            bytes.length,
            keystore,
            testRegistry,
            null,
            null,
          );
          expect(recoveryOffset, -1);

          final testKeystore = Keystore.debug(
            frames: framesSetLengthOffset(testFrames, frameBytes),
          );
          expectFrames(keystore.frames, testKeystore.frames);
          expect(await raf.position(), bytes.length);
        } finally {
          await raf.close();
        }
      });

      test('encrypted', () async {
        final bytes = _getBytes(frameBytesEncrypted);
        final keystore = Keystore.debug();
        final raf = await getTempRaf(bytes);
        try {
          final recoveryOffset = await FrameIoHelper().framesFromRaf(
            raf,
            bytes.length,
            keystore,
            testRegistry,
            testCipher,
            null,
          );
          expect(recoveryOffset, -1);

          final testKeystore = Keystore.debug(
            frames: framesSetLengthOffset(testFrames, frameBytesEncrypted),
          );
          expectFrames(keystore.frames, testKeystore.frames);
          expect(await raf.position(), bytes.length);
        } finally {
          await raf.close();
        }
      });

      test('empty file returns -1 and leaves raf open', () async {
        final keystore = Keystore.debug();
        final raf = await getTempRaf(const []);
        try {
          final recoveryOffset = await FrameIoHelper().framesFromRaf(
            raf,
            0,
            keystore,
            testRegistry,
            null,
            null,
          );
          expect(recoveryOffset, -1);
          expect(keystore.frames, isEmpty);
          expect(await raf.length(), 0);
        } finally {
          await raf.close();
        }
      });

      test(
        'handles file shorter than fileLength and leaves raf open',
        () async {
          final bytes = _getBytes(frameBytes);
          final keystore = Keystore.debug();
          final raf = await getTempRaf(bytes);
          try {
            final recoveryOffset = await FrameIoHelper().framesFromRaf(
              raf,
              bytes.length + 16,
              keystore,
              testRegistry,
              null,
              null,
            );
            expect(recoveryOffset, -1);

            final testKeystore = Keystore.debug(
              frames: framesSetLengthOffset(testFrames, frameBytes),
            );
            expectFrames(keystore.frames, testKeystore.frames);
            expect(await raf.position(), bytes.length);
          } finally {
            await raf.close();
          }
        },
      );
    });
  });
}
