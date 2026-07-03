import 'package:hive_ce/hive_ce.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'isolated_compaction_strategy.g.dart';

/// A sendable description of a [CompactionStrategy]
///
/// A [CompactionStrategy] is a function, and functions cannot be reliably sent
/// across an isolate boundary. Compaction also runs lazily inside the long
/// lived Hive isolate, potentially after the isolate that opened the box has
/// exited, so the strategy must be reconstructable entirely within the Hive
/// isolate.
///
/// Instead of passing a function, [IsolatedHive] accepts one of these sendable
/// descriptions and rebuilds the real [CompactionStrategy] on the isolate side
/// via [resolve].
@immutable
sealed class IsolatedCompactionStrategy {
  const IsolatedCompactionStrategy();

  /// Reconstructs the real [CompactionStrategy] function
  ///
  /// This is only ever called inside the Hive isolate. Implementations must not
  /// capture any state that cannot be sent across an isolate boundary.
  CompactionStrategy resolve();

  /// Compacts the box once more than [deletedThreshold] entries have been
  /// deleted and the ratio of deleted entries to total entries exceeds
  /// [deletedRatio]
  const factory IsolatedCompactionStrategy.threshold({
    required int deletedThreshold,
    required double deletedRatio,
  }) = _ThresholdCompactionStrategy;

  /// Never compacts the box
  const factory IsolatedCompactionStrategy.never() = _NeverCompactionStrategy;

  /// To json
  @internal
  Map<String, dynamic> toJson();

  /// From from
  @internal
  static IsolatedCompactionStrategy fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    return switch (type) {
      _ThresholdCompactionStrategy.type =>
        _ThresholdCompactionStrategy.fromJson(json),
      _NeverCompactionStrategy.type => const _NeverCompactionStrategy(),
      _ => throw HiveError('Unknown IsolatedCompactionStrategy type: $type'),
    };
  }
}

/// See [IsolatedCompactionStrategy.threshold]
@JsonSerializable()
@immutable
class _ThresholdCompactionStrategy extends IsolatedCompactionStrategy {
  static const type = 'threshold';

  /// The number of deleted entries required before compaction is considered
  final int deletedThreshold;

  /// The ratio of deleted entries to total entries required before compaction
  final double deletedRatio;

  /// Constructor
  const _ThresholdCompactionStrategy({
    required this.deletedThreshold,
    required this.deletedRatio,
  });

  /// From json
  factory _ThresholdCompactionStrategy.fromJson(Map<String, dynamic> json) =>
      _$ThresholdCompactionStrategyFromJson(json);

  @override
  CompactionStrategy resolve() {
    return (entries, deletedEntries) =>
        deletedEntries > deletedThreshold &&
        deletedEntries / entries > deletedRatio;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        ..._$ThresholdCompactionStrategyToJson(this),
      };
}

/// See [IsolatedCompactionStrategy.never]
@immutable
class _NeverCompactionStrategy extends IsolatedCompactionStrategy {
  static const type = 'never';

  /// Constructor
  const _NeverCompactionStrategy();

  @override
  CompactionStrategy resolve() => (_, __) => false;

  @override
  Map<String, dynamic> toJson() => {'type': type};
}
