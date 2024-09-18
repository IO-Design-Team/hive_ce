// ignore_for_file: overridden_fields

import 'dart:ui';

import 'package:hive_ce/hive.dart';

part 'color_adapter.g.dart';

/// TODO: Document this!
class ColorAdapter extends TypeAdapter<Color> {
  final _adapter = HiveColorAdapter();

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

  @override
  int get typeId => 200;
}

/// Hive wrapper for the fields in [Color]
@HiveType(typeId: 200)
class HiveColor {
  /// alpha
  @HiveField(0)
  final double a;

  /// red
  @HiveField(1)
  final double r;

  /// green
  @HiveField(2)
  final double g;

  /// blue
  @HiveField(3)
  final double b;

  /// color space
  @HiveField(4)
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
