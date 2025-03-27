import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/frame.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inspectable_box.g.dart';

/// An inspectable box
abstract interface class InspectableBox {
  /// The name of the box
  String get name;

  /// The box's type registry
  TypeRegistry get typeRegistry;

  /// Returns all of the frames currently loaded in the box
  Future<Iterable<InspectorFrame>> getFrames();

  /// Returns the value for the given [key].
  Future<Object?> getValue(Object key);

  /// Watch the box for changes
  Stream<BoxEvent> watch();
}

/// An inspector frame
@JsonSerializable()
class InspectorFrame {
  /// The frame key
  final Object? key;

  /// The frame value
  final Object? value;

  /// Whether the frame is lazy
  ///
  /// If true, the value will be null
  final bool lazy;

  /// Constructor
  const InspectorFrame({
    required this.key,
    required this.value,
    required this.lazy,
  });

  /// Copy with
  InspectorFrame copyWith({
    Object? value,
  }) =>
      InspectorFrame(
        key: key,
        value: value ?? this.value,
        lazy: lazy,
      );

  /// From frame
  factory InspectorFrame.fromFrame(Frame frame) => InspectorFrame(
        key: frame.key,
        value: frame.value,
        lazy: frame.lazy,
      );

  /// From json
  factory InspectorFrame.fromJson(Map<String, dynamic> json) =>
      _$InspectorFrameFromJson(json);

  /// To json
  Map<String, dynamic> toJson() => _$InspectorFrameToJson(this);
}
