import 'dart:io';
import 'dart:math' as math;

import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/report.dart';

const _databaseOrder = [
  'Hive CE',
  'Hive CE (lazy)',
  'IsolatedHive',
  'IsolatedHive (lazy)',
  'Hive v2',
  'Hive v4',
  'sqflite',
  'drift',
  'sembast',
  'ObjectBox',
];

const _font =
    "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif";
const _svgWidth = 860.0;
const _outerPad = 20.0;
const _colGap = 28.0;
const _rowGap = 24.0;
const _headerHeight = 56.0;
const _footerHeight = 20.0;
const _panelWidth = (_svgWidth - _outerPad * 2 - _colGap) / 2;
const _labelWidth = 122.0;
const _labelGap = 10.0;
const _valueWidth = 68.0;
const _valueGap = 8.0;
const _trackWidth =
    _panelWidth - _labelWidth - _labelGap - _valueGap - _valueWidth;
const _rowHeight = 22.0;
const _barHeight = 13.0;
const _dividerGap = 10.0;
const _panelHeaderHeight = 26.0;

void writeCharts(List<BenchmarkResult> results, {String directory = 'charts'}) {
  final dir = Directory(directory)..createSync(recursive: true);

  File.fromUri(dir.uri.resolve('speed.svg')).writeAsStringSync(
    _renderGrid(
      title: 'Standard Speed Benchmarks',
      subtitle:
          '${_formatCount(recordCount)} objects (10 int fields) · $benchmarkRuns-run average · lower is better',
      results: results,
      scenarios: const [
        Scenario.individualWrite,
        Scenario.batchWrite,
        Scenario.openAndRead,
        Scenario.query,
      ],
      clipOutliers: true,
    ),
  );

  File.fromUri(dir.uri.resolve('large_values.svg')).writeAsStringSync(
    _renderGrid(
      title: 'Large Binary Values (32 × 1 MiB)',
      subtitle:
          '32 MiB total payload · $benchmarkRuns-run average · lower is better',
      results: results,
      scenarios: const [Scenario.largeValueWrite, Scenario.largeValueOpen],
    ),
  );

  File.fromUri(dir.uri.resolve('memory.svg')).writeAsStringSync(
    _renderGrid(
      title: 'Memory and Database Size',
      subtitle:
          '${_formatCount(recordCount)} objects · peak RSS delta in fresh processes · lower is better',
      results: results,
      scenarios: const [
        Scenario.writePeak,
        Scenario.openPeak,
        Scenario.readPeak,
        Scenario.databaseSize,
      ],
    ),
  );
}

String _renderGrid({
  required String title,
  required String subtitle,
  required List<BenchmarkResult> results,
  required List<Scenario> scenarios,
  bool clipOutliers = false,
}) {
  final databases = _orderedDatabases(results);
  final hiveCount = databases.where(_isHiveCe).length;
  final hasDivider = hiveCount > 0 && hiveCount < databases.length;
  final panelHeight =
      _panelHeaderHeight +
      databases.length * _rowHeight +
      (hasDivider ? _dividerGap : 0) +
      4;

  final rows = (scenarios.length + 1) ~/ 2;
  var anyClipped = false;
  final panels = StringBuffer();

  for (var i = 0; i < scenarios.length; i++) {
    final col = i % 2;
    final row = i ~/ 2;
    final x = _outerPad + col * (_panelWidth + _colGap);
    final y = _outerPad + _headerHeight + row * (panelHeight + _rowGap);
    final clipped = _renderPanel(
      panels,
      x: x,
      y: y,
      scenario: scenarios[i],
      databases: databases,
      results: results,
      hasDivider: hasDivider,
      hiveCount: hiveCount,
      clipOutliers: clipOutliers,
    );
    anyClipped = anyClipped || clipped;
  }

  final height =
      _outerPad * 2 +
      _headerHeight +
      rows * panelHeight +
      (rows - 1) * _rowGap +
      (anyClipped ? _footerHeight : 0);

  final svg = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${_svgWidth.round()}" height="${height.round()}" '
      'viewBox="0 0 ${_svgWidth.round()} ${height.round()}">',
    )
    ..writeln(
      '  <rect x="0.5" y="0.5" width="${_svgWidth.round() - 1}" '
      'height="${height.round() - 1}" rx="10" fill="#ffffff" stroke="#e2e8f0"/>',
    )
    ..writeln(
      '  <text x="${_fmt(_outerPad)}" y="${_fmt(_outerPad + 18)}" '
      'font-family="$_font" font-size="16" font-weight="700" fill="#0f172a">'
      '${_escape(title)}</text>',
    )
    ..writeln(
      '  <text x="${_fmt(_outerPad)}" y="${_fmt(_outerPad + 36)}" '
      'font-family="$_font" font-size="11.5" fill="#64748b">'
      '${_escape(subtitle)}</text>',
    );

  // Legend top-right
  const legendY = _outerPad + 8;
  const legendX1 = _svgWidth - _outerPad - 196;
  const legendX2 = _svgWidth - _outerPad - 110;
  svg
    ..writeln(
      '  <rect x="${_fmt(legendX1)}" y="${_fmt(legendY)}" '
      'width="10" height="10" rx="2" fill="#0284c7"/>',
    )
    ..writeln(
      '  <text x="${_fmt(legendX1 + 15)}" y="${_fmt(legendY + 9)}" '
      'font-family="$_font" font-size="11" fill="#334155">Hive CE</text>',
    )
    ..writeln(
      '  <rect x="${_fmt(legendX2)}" y="${_fmt(legendY)}" '
      'width="10" height="10" rx="2" fill="#94a3b8"/>',
    )
    ..writeln(
      '  <text x="${_fmt(legendX2 + 15)}" y="${_fmt(legendY + 9)}" '
      'font-family="$_font" font-size="11" fill="#334155">Other databases</text>',
    )
    ..write(panels);

  if (anyClipped) {
    svg.writeln(
      '  <text x="${_fmt(_outerPad)}" y="${_fmt(height - 12)}" '
      'font-family="$_font" font-size="10.5" fill="#64748b">'
      '// Bar truncated to keep smaller results readable; label shows exact value.</text>',
    );
  }

  svg.writeln('</svg>');
  return svg.toString();
}

bool _renderPanel(
  StringBuffer out, {
  required double x,
  required double y,
  required Scenario scenario,
  required List<String> databases,
  required List<BenchmarkResult> results,
  required bool hasDivider,
  required int hiveCount,
  required bool clipOutliers,
}) {
  final values = <String, int?>{
    for (final result in results)
      if (result.scenario == scenario) result.database: result.value,
  };
  final numeric = [
    for (final db in databases)
      if (values[db] case final int value) value,
  ]..sort();

  final best = numeric.isEmpty ? null : numeric.first;
  final scaleMax = _scaleMax(numeric, clipOutliers: clipOutliers);
  final anyClipped = numeric.any((value) => value > scaleMax);

  out.writeln(
    '  <text x="${_fmt(x)}" y="${_fmt(y + 14)}" '
    'font-family="$_font" font-size="13" font-weight="600" fill="#0f172a">'
    '${_escape(scenario.label)}</text>',
  );

  final trackX = x + _labelWidth + _labelGap;
  final valueX = trackX + _trackWidth + _valueGap;

  for (var i = 0; i < databases.length; i++) {
    final db = databases[i];
    final extraY = hasDivider && i >= hiveCount ? _dividerGap : 0.0;
    final rowY = y + _panelHeaderHeight + i * _rowHeight + extraY;

    if (hasDivider && i == hiveCount) {
      final lineY = rowY - _dividerGap / 2 - 2;
      out.writeln(
        '  <line x1="${_fmt(x)}" y1="${_fmt(lineY)}" '
        'x2="${_fmt(x + _panelWidth)}" y2="${_fmt(lineY)}" '
        'stroke="#e2e8f0" stroke-width="1"/>',
      );
    }

    final value = values[db];
    final isHive = _isHiveCe(db);
    final isBest = value != null && value == best;
    final barY = rowY + (_rowHeight - _barHeight) / 2 - 2;
    final textY = rowY + _rowHeight / 2 + 2;

    out
      ..writeln(
        '  <text x="${_fmt(x + _labelWidth)}" y="${_fmt(textY)}" '
        'text-anchor="end" font-family="$_font" font-size="11.5" '
        'font-weight="${isHive ? '600' : '400'}" '
        'fill="${isHive ? '#0f172a' : '#475569'}">${_escape(db)}</text>',
      )
      ..writeln(
        '  <rect x="${_fmt(trackX)}" y="${_fmt(barY)}" '
        'width="${_fmt(_trackWidth)}" height="${_fmt(_barHeight)}" '
        'rx="3" fill="#f1f5f9"/>',
      );

    if (value != null && scaleMax > 0) {
      final clipped = value > scaleMax;
      final barWidth = clipped
          ? _trackWidth
          : math.max<double>(3, (value / scaleMax) * _trackWidth);
      final fill = isHive
          ? (isBest ? '#0369a1' : '#0284c7')
          : (isBest ? '#475569' : '#94a3b8');

      out.writeln(
        '  <rect x="${_fmt(trackX)}" y="${_fmt(barY)}" '
        'width="${_fmt(barWidth)}" height="${_fmt(_barHeight)}" '
        'rx="3" fill="$fill"/>',
      );

      if (clipped) {
        final bx = trackX + _trackWidth - 15;
        out
          ..writeln(
            '  <line x1="${_fmt(bx)}" y1="${_fmt(barY + _barHeight + 1)}" '
            'x2="${_fmt(bx + 4)}" y2="${_fmt(barY - 1)}" '
            'stroke="#ffffff" stroke-width="2.2"/>',
          )
          ..writeln(
            '  <line x1="${_fmt(bx + 5)}" y1="${_fmt(barY + _barHeight + 1)}" '
            'x2="${_fmt(bx + 9)}" y2="${_fmt(barY - 1)}" '
            'stroke="#ffffff" stroke-width="2.2"/>',
          );
      }
    }

    final label = value == null ? 'Timed out' : _formatValue(scenario, value);
    out.writeln(
      '  <text x="${_fmt(valueX)}" y="${_fmt(textY)}" '
      'font-family="$_font" font-size="11" '
      'font-weight="${isBest ? '700' : '400'}" '
      'fill="${isBest ? '#0f172a' : '#475569'}">${_escape(label)}</text>',
    );
  }

  return anyClipped;
}

double _scaleMax(List<int> sortedValues, {required bool clipOutliers}) {
  if (sortedValues.isEmpty) return 0;
  final max = sortedValues.last.toDouble();
  if (!clipOutliers || sortedValues.length < 4) return max;

  final anchor = sortedValues[sortedValues.length - 3].toDouble();
  if (anchor <= 0 || max <= anchor * 3.5) return max;

  final maxNonOutlier = sortedValues
      .where((value) => value <= anchor * 3.5)
      .last
      .toDouble();
  return maxNonOutlier * 1.15;
}

String _formatCount(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (match) => '${match[1]},',
);

List<String> _orderedDatabases(List<BenchmarkResult> results) {
  final present = {for (final result in results) result.database};
  return [
    for (final db in _databaseOrder)
      if (present.contains(db)) db,
    for (final db in present)
      if (!_databaseOrder.contains(db)) db,
  ];
}

bool _isHiveCe(String database) =>
    database.startsWith('Hive CE') || database.startsWith('IsolatedHive');

String _formatValue(Scenario scenario, int value) {
  if (!scenario.speed) {
    return '${(value / (1024 * 1024)).toStringAsFixed(2)} MiB';
  }
  if (value < 1000) return '$value µs';
  if (value < 10000) return '${(value / 1000).toStringAsFixed(2)} ms';
  if (value < 1000000) return '${(value / 1000).toStringAsFixed(1)} ms';
  return '${(value / 1000000).toStringAsFixed(2)} s';
}

String _fmt(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
