import 'package:flutter/widgets.dart';
import 'package:hive_ce/hive.dart';

/// TODO: Document this!
class ColorAdapter extends TypeAdapter<Color> {
  @override
  Color read(BinaryReader reader) => Color(reader.readInt());

  @override
  // TODO: Merge https://github.com/IO-Design-Team/hive_ce/pull/27 when Flutter 3.26 lands
  // ignore: deprecated_member_use
  void write(BinaryWriter writer, Color obj) => writer.writeInt(obj.value);

  @override
  int get typeId => 200;
}
