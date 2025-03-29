import 'package:hive_ce_inspector/model/hive_internal.dart';

class BoxData {
  final String name;
  final Map<Object, InspectorFrame> frames;
  final bool open;

  BoxData({
    required this.name,
    Map<Object, InspectorFrame>? frames,
    this.open = true,
  }) : frames = frames ?? {};

  BoxData copyWith({bool? open}) =>
      BoxData(name: name, frames: frames, open: open ?? this.open);
}
