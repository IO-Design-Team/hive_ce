import 'dart:typed_data';

import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:test/test.dart';

import '../common.dart';
import '../frames.dart';

void main() {
  test('verbatim frames', () {
    for (final frame in testFrames) {
      final writer = BinaryWriterImpl(testRegistry);
      writer.write(frame.value);

      final encodedValue = writer.toBytes();
      final encodedFrame = Frame(frame.key, encodedValue);

      final verbatimWriter = BinaryWriterImpl(testRegistry);
      verbatimWriter.writeFrame(encodedFrame, verbatim: true);

      final verbatimBytes = verbatimWriter.toBytes();
      final verbatimReader = BinaryReaderImpl(verbatimBytes, testRegistry);
      final decodedFrame =
          expectNotNull(verbatimReader.readFrame(verbatim: true));

      expect(decodedFrame.key, encodedFrame.key);
      expect(decodedFrame.value, encodedFrame.value);
      expect(
        identical(
          (decodedFrame.value as Uint8List).buffer,
          verbatimBytes.buffer,
        ),
        isFalse,
      );

      final reader =
          BinaryReaderImpl(decodedFrame.value as Uint8List, testRegistry);
      final decodedValue = reader.read();

      expect(decodedValue, frame.value);
    }
  });
}
