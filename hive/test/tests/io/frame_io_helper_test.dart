@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:hive_ce/src/box/keystore.dart';
import 'package:hive_ce/src/io/frame_io_helper.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../common.dart';
import '../frames.dart';

Uint8List _getBytes(List<Uint8List> list) {
  final builder = BytesBuilder();
  for (final b in list) {
    builder.add(b);
  }
  return builder.toBytes();
}

Uint8List _encodeFrames(List<Frame> frames) {
  final writer = BinaryWriterImpl(testRegistry);
  var offset = 0;
  for (final frame in frames) {
    final length = writer.writeFrame(frame);
    frame
      ..length = length
      ..offset = offset;
    offset += length;
  }
  return writer.toBytes();
}

Uint8List _filledBytes(int length, int fill) =>
    Uint8List(length)..fillRange(0, length, fill);

Future<void> _expectStreamedFrames(
  List<Frame> frames, {
  bool verbatim = false,
}) async {
  final bytes = _encodeFrames(frames);
  expect(bytes.length, greaterThan(1 << 20));

  final keystore = Keystore.debug();
  final recoveryOffset = await _FrameIoHelperTest(bytes).framesFromFile(
    'null',
    keystore,
    testRegistry,
    null,
    null,
    verbatim: verbatim,
  );
  expect(recoveryOffset, -1);

  final expectedFrames = verbatim
      ? [
          for (final frame in frames)
            if (frame.deleted)
              frame
            else
              Frame(
                frame.key,
                (BinaryWriterImpl(testRegistry)..write(frame.value)).toBytes(),
                length: frame.length,
                offset: frame.offset,
              ),
        ]
      : frames;
  final expectedKeystore = Keystore.debug(frames: expectedFrames);
  expectFrames(keystore.frames, expectedKeystore.frames);
  expect(
    keystore.frames.map((f) => f.offset),
    expectedKeystore.frames.map((f) => f.offset),
  );

  if (verbatim) {
    for (final frame in keystore.frames) {
      if (!frame.deleted) {
        final value = frame.value as Uint8List;
        expect(value.buffer.lengthInBytes, value.length);
      }
    }
  }
}

@immutable
class _FrameIoHelperTest extends FrameIoHelper {
  final Uint8List bytes;

  _FrameIoHelperTest(this.bytes);

  @override
  Future<RandomAccessFile> openFile(String path) {
    return getTempRaf(bytes);
  }
}

void main() {
  group('FrameIoHelper', () {
    group('.keysFromFile()', () {
      test('frame', () async {
        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(_getBytes(frameBytes));
        final recoveryOffset =
            await ioHelper.keysFromFile('null', keystore, null, null);
        expect(recoveryOffset, -1);

        final testKeystore = Keystore.debug(
          frames: lazyFrames(framesSetLengthOffset(testFrames, frameBytes)),
        );

        expectFrames(keystore.frames, testKeystore.frames);
      });

      test('encrypted', () async {
        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(_getBytes(frameBytesEncrypted));
        final recoveryOffset =
            await ioHelper.keysFromFile('null', keystore, testCipher, null);
        expect(recoveryOffset, -1);

        final testKeystore = Keystore.debug(
          frames: lazyFrames(
            framesSetLengthOffset(testFrames, frameBytesEncrypted),
          ),
        );

        expectFrames(keystore.frames, testKeystore.frames);
      });
    });

    group('.framesFromFile()', () {
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

      test('empty file', () async {
        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(Uint8List(0));
        final recoveryOffset = await ioHelper.framesFromFile(
          'null',
          keystore,
          testRegistry,
          null,
          null,
        );
        expect(recoveryOffset, -1);
        expect(keystore.frames, isEmpty);
      });

      test('file shorter than minimum frame', () async {
        final keystore = Keystore.debug();
        final recoveryOffset = await _FrameIoHelperTest(
          Uint8List.fromList([1, 2]),
        ).framesFromFile('null', keystore, testRegistry, null, null);
        expect(recoveryOffset, 0);
        expect(keystore.frames, isEmpty);
      });

      group('returns exact offset on truncated or corrupted tail', () {
        Future<void> expectTailRecovery(List<int> tail) async {
          final validBytes = _getBytes(frameBytes);
          final bytes = Uint8List.fromList([...validBytes, ...tail]);
          final keystore = Keystore.debug();
          final recoveryOffset = await _FrameIoHelperTest(bytes)
              .framesFromFile('null', keystore, testRegistry, null, null);
          expect(recoveryOffset, validBytes.length);
          expectFrames(
            keystore.frames,
            Keystore.debug(
              frames: framesSetLengthOffset(testFrames, frameBytes),
            ).frames,
          );
        }

        test('with trailing < 4 bytes', () async {
          await expectTailRecovery([1, 2]);
        });

        test('with invalid frameLength < 8', () async {
          await expectTailRecovery([4, 0, 0, 0]);
        });

        test('with corrupt oversized frameLength', () async {
          await expectTailRecovery([0xFF, 0xFF, 0xFF, 0xFF, 1, 2, 3, 4]);
        });

        test('with corrupted CRC', () async {
          final corruptedFrame = Uint8List.fromList(frameBytes.last);
          corruptedFrame[corruptedFrame.length - 1] ^= 0x01;
          await expectTailRecovery(corruptedFrame);
        });
      });

      group('streaming (> 1 MiB)', () {
        test('streams multiple chunks', () async {
          final frames = [
            // Leaves 2 bytes in the first 1 MiB chunk so the next frame's
            // length header straddles the chunk boundary.
            Frame('a', _filledBytes((1 << 20) - 18, 1)),
            Frame('b', _filledBytes(512 * 1024, 2)),
            Frame('c', _filledBytes(600 * 1024, 3)),
          ];
          await _expectStreamedFrames(frames);
          expect(frames.first.length, (1 << 20) - 2);
        });

        test('streams multiple chunks verbatim', () async {
          await _expectStreamedFrames(
            [
              for (var i = 0; i < 4; i++)
                Frame('v$i', _filledBytes(300 * 1024, i + 1)),
            ],
            verbatim: true,
          );
        });

        test('streams single frame larger than 1 MiB', () async {
          await _expectStreamedFrames([
            Frame('before', 'start'),
            Frame('huge', _filledBytes((1 << 20) + 128 * 1024, 1)),
            Frame('after', 'end'),
          ]);
        });
      });
    });
  });
}
