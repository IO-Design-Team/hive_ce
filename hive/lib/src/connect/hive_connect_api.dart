import 'package:hive_ce/src/binary/frame.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'hive_connect_api.g.dart';

/// Box inspection actions
enum ConnectAction {
  /// List all boxes currently set up for inspection
  listBoxes,

  /// Get all frames for a given box
  getBoxFrames,

  /// Load the value of a given key
  loadValue;

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
@immutable
class InspectorFrame {
  /// The frame key
  final Object key;

  /// The frame value
  final Object? value;

  /// Whether the frame is lazy
  ///
  /// If true, the value will be null
  final bool lazy;

  /// Whether the frame is deleted
  final bool deleted;

  /// Constructor
  const InspectorFrame({
    required this.key,
    required this.value,
    this.lazy = false,
    this.deleted = false,
  });

  /// Lazy
  const InspectorFrame.lazy(this.key)
      : value = null,
        lazy = true,
        deleted = false;

  /// From frame
  factory InspectorFrame.fromFrame(Frame frame) => InspectorFrame(
        key: frame.key,
        value: frame.value,
        lazy: frame.lazy,
        deleted: frame.deleted,
      );

  /// From json
  factory InspectorFrame.fromJson(Map<String, dynamic> json) =>
      _$InspectorFrameFromJson(json);

  /// To json
  Map<String, dynamic> toJson() => _$InspectorFrameToJson(this);

  /// Copy with
  InspectorFrame copyWith({
    required Object? value,
    bool? lazy,
  }) =>
      InspectorFrame(
        key: key,
        value: value,
        lazy: lazy ?? this.lazy,
        deleted: deleted,
      );
}

/// Payload for a box event
@JsonSerializable()
@immutable
class BoxEventPayload {
  /// The box name
  final String box;

  /// The event frame
  final InspectorFrame frame;

  /// Constructor
  const BoxEventPayload({
    required this.box,
    required this.frame,
  });

  /// From json
  factory BoxEventPayload.fromJson(Map<String, dynamic> json) =>
      _$BoxEventPayloadFromJson(json);

  /// To json
  Map<String, dynamic> toJson() => _$BoxEventPayloadToJson(this);

  /// Copy with
  BoxEventPayload copyWith({
    InspectorFrame? frame,
  }) =>
      BoxEventPayload(
        box: box,
        frame: frame ?? this.frame,
      );
}
