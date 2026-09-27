import 'package:flutter/material.dart' as flutter show TimeOfDay;
import 'package:hive_ce/hive_ce.dart';
import 'package:material_ui/material_ui.dart' as material_ui show TimeOfDay;

abstract class _TimeOfDayAdapter<T> extends TypeAdapter<T> {
  static const _defaultTypeId = 201;

  const _TimeOfDayAdapter({int? typeId}) : typeId = typeId ?? _defaultTypeId;

  @override
  final int typeId;

  T _create(int hour, int minute);

  int _hour(T obj);

  int _minute(T obj);

  @override
  T read(BinaryReader reader) {
    final totalMinutes = reader.readInt();
    return _create(totalMinutes ~/ 60, totalMinutes % 60);
  }

  @override
  void write(BinaryWriter writer, T obj) {
    writer.writeInt(_hour(obj) * 60 + _minute(obj));
  }
}

/// A [TypeAdapter] for the `TimeOfDay` class from `package:flutter/material.dart`
///
/// Uses the same binary format and default type id as
/// [MaterialUiTimeOfDayAdapter]
class TimeOfDayAdapter extends _TimeOfDayAdapter<flutter.TimeOfDay> {
  /// Constructor
  const TimeOfDayAdapter({super.typeId});

  @override
  flutter.TimeOfDay _create(int hour, int minute) =>
      flutter.TimeOfDay(hour: hour, minute: minute);

  @override
  int _hour(flutter.TimeOfDay obj) => obj.hour;

  @override
  int _minute(flutter.TimeOfDay obj) => obj.minute;
}

/// A [TypeAdapter] for the `TimeOfDay` class from `package:material_ui`
///
/// Uses the same binary format and default type id as [TimeOfDayAdapter]
class MaterialUiTimeOfDayAdapter
    extends _TimeOfDayAdapter<material_ui.TimeOfDay> {
  /// Constructor
  const MaterialUiTimeOfDayAdapter({super.typeId});

  @override
  material_ui.TimeOfDay _create(int hour, int minute) =>
      material_ui.TimeOfDay(hour: hour, minute: minute);

  @override
  int _hour(material_ui.TimeOfDay obj) => obj.hour;

  @override
  int _minute(material_ui.TimeOfDay obj) => obj.minute;
}
