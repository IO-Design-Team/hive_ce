import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

/// TODO: Document this!
class TimeOfDayAdapter extends TypeAdapter<TimeOfDay> {
  static const _defaultTypeId = 201;

  /// Constructor
  const TimeOfDayAdapter({int? typeId}) : typeId = typeId ?? _defaultTypeId;

  @override
  final int typeId;

  @override
  TimeOfDay read(BinaryReader reader) {
    final totalMinutes = reader.readInt();
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  @override
  void write(BinaryWriter writer, TimeOfDay obj) {
    writer.writeInt(obj.hour * 60 + obj.minute);
  }
}
