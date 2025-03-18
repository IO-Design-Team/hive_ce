import 'dart:typed_data';

import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:test/test.dart';

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

      final verbatimReader =
          BinaryReaderImpl(verbatimWriter.toBytes(), testRegistry);
      final decodedFrame = verbatimReader.readFrame(verbatim: true)!;

      expect(decodedFrame.key, encodedFrame.key);
      expect(decodedFrame.value, encodedFrame.value);

      final reader =
          BinaryReaderImpl(decodedFrame.value as Uint8List, testRegistry);
      final decodedValue = reader.read();

      expect(decodedValue, frame.value);
    }
  });
}
