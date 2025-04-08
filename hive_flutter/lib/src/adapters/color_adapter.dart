import 'dart:ui';

import 'package:hive_ce/hive.dart';

/// TODO: Document this!
class ColorAdapter extends TypeAdapter<Color> {
  static const _defaultTypeId = 200;

  /// Constructor
  ColorAdapter({int? typeId}) : typeId = typeId ?? _defaultTypeId;

  @override
  final int typeId;

  late final _adapter = HiveColorAdapter(typeId: typeId);

  @override
  Color read(BinaryReader reader) {
    if (reader.availableBytes == 8) {
      // Support for reading data created by the old ColorAdapter
      return Color(reader.readInt());
    } else {
      return _adapter.read(reader).toColor();
    }
  }

  @override
  void write(BinaryWriter writer, Color obj) =>
      _adapter.write(writer, HiveColor.fromColor(obj));
}

/// Hive wrapper for the fields in [Color]
class HiveColor {
  /// alpha
  final double a;

  /// red
  final double r;

  /// green
  final double g;

  /// blue
  final double b;

  /// color space
  final String colorSpace;

  /// Constructor
  const HiveColor({
    required this.a,
    required this.r,
    required this.g,
    required this.b,
    required this.colorSpace,
  });

  /// Convert a [Color] to a [HiveColor]
  HiveColor.fromColor(Color color)
      : a = color.a,
        r = color.r,
        g = color.g,
        b = color.b,
        colorSpace = color.colorSpace.name;

  /// Convert a [HiveColor] to a [Color]
  Color toColor() => Color.from(
        alpha: a,
        red: r,
        green: g,
        blue: b,
        colorSpace: ColorSpace.values.byName(colorSpace),
      );
}

/// Adapter for the new Color fields
class HiveColorAdapter extends TypeAdapter<HiveColor> {
  /// Constructor
  HiveColorAdapter({required this.typeId});

  @override
  final int typeId;

  @override
  HiveColor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveColor(
      a: (fields[0] as num).toDouble(),
      r: (fields[1] as num).toDouble(),
      g: (fields[2] as num).toDouble(),
      b: (fields[3] as num).toDouble(),
      colorSpace: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HiveColor obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.a)
      ..writeByte(1)
      ..write(obj.r)
      ..writeByte(2)
      ..write(obj.g)
      ..writeByte(3)
      ..write(obj.b)
      ..writeByte(4)
      ..write(obj.colorSpace);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveColorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
