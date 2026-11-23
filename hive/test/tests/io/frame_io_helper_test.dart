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

Uint8List _encodeVerbatimValue(Object? value) {
  final writer = BinaryWriterImpl(testRegistry);
  writer.write(value);
  return writer.toBytes();
}

Uint8List _patternBytes(int length, int seed) {
  return Uint8List.fromList(
    List<int>.generate(length, (i) => (i + seed) & 0xFF),
  );
}

void _expectFrameOffsets(Iterable<Frame> actual, Iterable<Frame> expected) {
  final actualList = actual.toList();
  final expectedList = expected.toList();
  expect(actualList.length, expectedList.length);
  for (var i = 0; i < expectedList.length; i++) {
    expect(actualList[i].offset, expectedList[i].offset);
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
    });

    group('.framesFromFile() streaming (> 1 MiB)', () {
      test('streams multiple chunks', () async {
        final frames = <Frame>[
          for (var i = 0; i < 8; i++)
            Frame('chunk$i', _patternBytes(256 * 1024, i * 17)),
          Frame('overwrite', _patternBytes(1024, 1)),
          Frame('overwrite', 'updated_value'),
          Frame('null_key', null),
          Frame('deleted_key', _patternBytes(2048, 9)),
          Frame.deleted('deleted_key'),
          Frame(42, 'int_key_value'),
        ];
        final bytes = _encodeFrames(frames);
        expect(bytes.length, greaterThan(1 << 20));

        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(bytes);
        final recoveryOffset = await ioHelper.framesFromFile(
          'null',
          keystore,
          testRegistry,
          null,
          null,
        );
        expect(recoveryOffset, -1);

        final expectedKeystore = Keystore.debug(frames: frames);
        expectFrames(keystore.frames, expectedKeystore.frames);
        _expectFrameOffsets(keystore.frames, expectedKeystore.frames);
      });

      test(
        'streams multiple chunks verbatim without sharing chunk buffer',
        () async {
          final frames = <Frame>[
            for (var i = 0; i < 11; i++)
              Frame('v$i', _patternBytes(300 * 1024, i * 29)),
            Frame('null_v', null),
            Frame('del_v', 'temp'),
            Frame.deleted('del_v'),
          ];
          final bytes = _encodeFrames(frames);
          expect(bytes.length, greaterThan(3 * (1 << 20)));

          final expectedVerbatimFrames = <Frame>[
            for (final frame in frames)
              if (frame.deleted)
                frame
              else
                Frame(
                  frame.key,
                  _encodeVerbatimValue(frame.value),
                  length: frame.length,
                  offset: frame.offset,
                ),
          ];

          final keystore = Keystore.debug();
          final ioHelper = _FrameIoHelperTest(bytes);
          final recoveryOffset = await ioHelper.framesFromFile(
            'null',
            keystore,
            testRegistry,
            null,
            null,
            verbatim: true,
          );
          expect(recoveryOffset, -1);

          final expectedKeystore =
              Keystore.debug(frames: expectedVerbatimFrames);
          expectFrames(keystore.frames, expectedKeystore.frames);
          _expectFrameOffsets(keystore.frames, expectedKeystore.frames);

          final actualFrames = keystore.frames.toList();
          final expectedSnapshots = <Uint8List>[
            for (final frame in actualFrames)
              Uint8List.fromList(frame.value as Uint8List),
          ];
          for (final frame in actualFrames) {
            final value = frame.value as Uint8List;
            expect(value.buffer.lengthInBytes, value.length);
          }

          (actualFrames.first.value as Uint8List)[0] ^= 0xFF;
          for (var i = 1; i < actualFrames.length; i++) {
            expect(actualFrames[i].value, expectedSnapshots[i]);
          }
        },
      );

      test('streams single frame larger than 1 MiB', () async {
        final frames = <Frame>[
          Frame('before', 'start'),
          Frame('huge', _patternBytes((1 << 20) + 128 * 1024, 55)),
          Frame('after', 'end'),
        ];
        final bytes = _encodeFrames(frames);
        expect(bytes.length, greaterThan(1 << 20));

        final keystore = Keystore.debug();
        final ioHelper = _FrameIoHelperTest(bytes);
        final recoveryOffset = await ioHelper.framesFromFile(
          'null',
          keystore,
          testRegistry,
          null,
          null,
        );
        expect(recoveryOffset, -1);

        final expectedKeystore = Keystore.debug(frames: frames);
        expectFrames(keystore.frames, expectedKeystore.frames);
        _expectFrameOffsets(keystore.frames, expectedKeystore.frames);
      });
    });
  });
}
