import 'package:hive_ce/src/util/json_annotation.dart';

part 'lock_props.g.dart';

/// Properties stored in box lock files
@JsonSerializable()
class LockProps {
  /// Whether the box is isolated
  final bool isolated;

  /// Constructor
  const LockProps({
    this.isolated = false,
  });

  /// From json
  factory LockProps.fromJson(Map<String, dynamic> json) =>
      _$LockPropsFromJson(json);

  /// To json
  Map<String, dynamic> toJson() => _$LockPropsToJson(this);
}
