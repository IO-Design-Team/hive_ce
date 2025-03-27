import 'package:hive_ce/src/binary/frame.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hive_connect_api.g.dart';

/// Box inspection actions
enum ConnectAction {
  /// List all boxes currently set up for inspection
  listBoxes,

  /// Get all frames for a given box
  getBoxFrames,

  /// Read the value of a given key
  getValue;

  /// The method name
  String get method => 'ext.hive_ce.$name';
}

/// Box inspection events
enum ConnectEvent {
  /// A box was added for inspection
  boxRegistered,

  /// A box was removed from inspection
  boxUnregistered,

  /// A box event occurred
  boxEvent;

  /// The event name
  String get event => 'ext.hive_ce.$name';
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

  /// Copy with
  InspectorFrame copyWith({
    Object? value,
    bool? lazy,
  }) =>
      InspectorFrame(
        key: key,
        value: value ?? this.value,
        lazy: lazy ?? this.lazy,
      );
}

/// Payload for a box event
@JsonSerializable()
class BoxEventPayload {
  /// The box name
  final String name;

  /// The event key
  final Object? key;

  /// The encoded event value
  final List<int>? value;

  /// Whether the event is a deletion
  final bool deleted;

  /// Constructor
  const BoxEventPayload({
    required this.name,
    required this.key,
    required this.value,
    required this.deleted,
  });

  /// From json
  factory BoxEventPayload.fromJson(Map<String, dynamic> json) =>
      _$BoxEventPayloadFromJson(json);

  /// To json
  Map<String, dynamic> toJson() => _$BoxEventPayloadToJson(this);
}
