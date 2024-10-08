// TODO: Remove with https://github.com/IO-Design-Team/hive_ce/pull/27
// ignore_for_file: deprecated_member_use

import 'dart:ui' show Color;

import 'package:hive_ce_flutter/adapters.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('ColorAdapter', () {
    test('.read()', () {
      const color = Color(0xFF000000);
      final BinaryReader binaryReader = MockBinaryReader();
      when(binaryReader.readInt()).thenReturn(color.value);

      final readColor = ColorAdapter().read(binaryReader);
      verify(binaryReader.readInt());
      expect(readColor, color);
    });

    test('.write()', () {
      const color = Color(0xFF000000);
      final BinaryWriter binaryWriter = MockBinaryWriter();

      ColorAdapter().write(binaryWriter, color);
      verify(binaryWriter.writeInt(color.value));
    });
  });
}
