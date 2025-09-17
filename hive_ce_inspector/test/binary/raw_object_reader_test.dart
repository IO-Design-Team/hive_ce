import 'package:flutter/material.dart';
import 'package:hive_ce/src/binary/raw_object_reader.dart';
import 'package:hive_ce/src/binary/raw_object_writer.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hive_ce_inspector/util/base_schema.dart';
import 'package:test/test.dart';

void main() {
  group('RawObjectReader', () {
    test('Color', () {
      final typeRegistry = TypeRegistryImpl()..registerAdapter(ColorAdapter());

      const color = Color(0xFF123456);

      final bw = RawObjectWriter(typeRegistry);
      bw.write(color);

      final br = RawObjectReader(baseSchema, bw.toBytes());
      final raw = br.read() as RawObject;
      expect(raw.name, 'Color');
      expect(raw.fields[0].name, 'a');
      expect(raw.fields[0].value, color.a);
      expect(raw.fields[1].name, 'r');
      expect(raw.fields[1].value, color.r);
      expect(raw.fields[2].name, 'g');
      expect(raw.fields[2].value, color.g);
      expect(raw.fields[3].name, 'b');
      expect(raw.fields[3].value, color.b);
      expect(raw.fields[4].name, 'colorSpace');
      expect(raw.fields[4].value, color.colorSpace.name);
    });

    test('TimeOfDay', () {
      final typeRegistry = TypeRegistryImpl()
        ..registerAdapter(const TimeOfDayAdapter());

      const hour = 12;
      const minute = 30;

      final bw = RawObjectWriter(typeRegistry);
      bw.write(const TimeOfDay(hour: hour, minute: minute));

      final br = RawObjectReader({}, bw.toBytes());
      final raw = br.read() as String;
      expect(raw, '$hour:$minute');
    });
  });
}
