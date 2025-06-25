import 'package:hive_ce_inspector/model/hive_internal.dart';

class BoxData {
  final String name;
  final Map<Object, InspectorFrame> frames;
  final bool open;
  final bool loaded;

  BoxData({
    required this.name,
    Map<Object, InspectorFrame>? frames,
    this.open = true,
    this.loaded = false,
  }) : frames = frames ?? {};

  BoxData copyWith({bool? open}) => BoxData(
    name: name,
    frames: frames,
    open: open ?? this.open,
    loaded: loaded,
  );
}
