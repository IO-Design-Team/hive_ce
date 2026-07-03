// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, require_trailing_commas

part of 'isolated_compaction_strategy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ThresholdCompactionStrategy _$ThresholdCompactionStrategyFromJson(
        Map<String, dynamic> json) =>
    _ThresholdCompactionStrategy(
      deletedThreshold: (json['deletedThreshold'] as num?)?.toInt() ?? 60,
      deletedRatio: (json['deletedRatio'] as num?)?.toDouble() ?? 0.15,
    );

Map<String, dynamic> _$ThresholdCompactionStrategyToJson(
        _ThresholdCompactionStrategy instance) =>
    <String, dynamic>{
      'deletedThreshold': instance.deletedThreshold,
      'deletedRatio': instance.deletedRatio,
    };
