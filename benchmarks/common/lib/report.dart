import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:storage_benchmark/benchmark.dart';
import 'package:storage_benchmark/charts.dart';

enum Workload { standard, largeValues, memory }

enum Scenario {
  individualWrite('Individual writes'),
  batchWrite('Batch writes'),
  openAndRead('Open and read'),
  query('Query'),
  largeValueWrite('1 MiB batch write', Workload.largeValues),
  largeValueOpen('1 MiB reopen', Workload.largeValues),
  writePeak('Batch write peak', Workload.memory),
  openPeak('Open peak', Workload.memory),
  readPeak('Open and read peak', Workload.memory),
  databaseSize('Database size', Workload.memory);

  final String label;
  final Workload workload;

  const Scenario(this.label, [this.workload = Workload.standard]);

  bool get speed => workload != Workload.memory;
  int get valueCount =>
      workload == Workload.largeValues ? largeValueCount : recordCount;
  String get csvUnit => speed ? 'us' : 'bytes';
  String get displayUnit => speed ? 'ms' : 'MiB';

  String format(int value) => speed
      ? (value / 1000).toStringAsFixed(3)
      : (value / (1024 * 1024)).toStringAsFixed(2);
}

@immutable
class BenchmarkResult {
  final Scenario scenario;
  final String database;

  /// A timed-out speed measurement has no value.
  final int? value;

  const BenchmarkResult(this.scenario, this.database, {required this.value});

  factory BenchmarkResult.fromJson(Map<String, dynamic> json) =>
      BenchmarkResult(
        Scenario.values.byName(json['scenario'] as String),
        json['database'] as String,
        value: json['value'] as int?,
      );

  Map<String, Object?> toJson() => {
    'scenario': scenario.name,
    'database': database,
    'value': value,
  };

  String get displayValue => switch (value) {
    final int value => scenario.format(value),
    null => 'Timed out',
  };
}

List<BenchmarkResult> readResultFile(String path) {
  if (path.endsWith('.csv')) {
    return [
      for (final line in File(path).readAsLinesSync().skip(1))
        if (line.trim().isNotEmpty) _parseCsvRow(line),
    ];
  }
  return [
    for (final result in jsonDecode(File(path).readAsStringSync()) as List)
      BenchmarkResult.fromJson(result as Map<String, dynamic>),
  ];
}

BenchmarkResult _parseCsvRow(String line) {
  final match = RegExp(
    r'^([^,]+),"((?:[^"]|"")*)",\d+,[^,]+,(\d*),[^,]+$',
  ).firstMatch(line);
  if (match case final match?) {
    final scenario = match.group(1);
    final database = match.group(2);
    final rawValue = match.group(3);
    if (scenario != null && database != null && rawValue != null) {
      return BenchmarkResult(
        Scenario.values.byName(scenario),
        database.replaceAll('""', '"'),
        value: rawValue.isEmpty ? null : int.parse(rawValue),
      );
    }
  }
  throw FormatException('Invalid CSV benchmark row', line);
}

void writeResultFile(String path, List<BenchmarkResult> results) =>
    File(path).writeAsStringSync(jsonEncode(results));

void writeReport(List<BenchmarkResult> results) {
  final speed = results.where((result) => result.scenario.speed);
  final memory = results.where((result) => !result.scenario.speed);
  final markdown = StringBuffer('# Storage benchmarks\n\n')
    ..writeln(
      'Each result is the average of $benchmarkRuns runs. '
      'The standard workloads use $recordCount values each.\n',
    )
    ..writeln('## Speed\n')
    ..writeln(
      'The open and read timing loads keys for lazy boxes and values for other databases. '
      'The query matches ${recordCount ~/ 10} values.\n',
    )
    ..writeln(
      'Bold marks the fastest time in each column. The 1 MiB columns use '
      '$largeValueCount values per run. '
      'Batch writes include any required flush. Reopen measures opening the database.\n',
    )
    ..writeln(
      _table(
        speed,
        Scenario.values.where((scenario) => scenario.speed),
        boldFastest: true,
      ),
    )
    ..writeln('## Memory and database size\n')
    ..writeln(
      _table(memory, Scenario.values.where((scenario) => !scenario.speed)),
    );

  File('benchmark_results.md').writeAsStringSync(markdown.toString());
  File('benchmark_results.csv').writeAsStringSync(_csv([...speed, ...memory]));
  writeCharts(results);
  stdout.writeln(
    'Results written to benchmark_results.md, benchmark_results.csv, and charts/',
  );
}

String _csv(Iterable<BenchmarkResult> results) {
  final csv = StringBuffer('scenario,database,values,unit,result,status\n');
  for (final row in results) {
    final name = row.database.replaceAll('"', '""');
    csv.writeln(
      [
        row.scenario.name,
        '"$name"',
        row.scenario.valueCount,
        row.scenario.csvUnit,
        row.value ?? '',
        row.value == null ? 'timedOut' : 'ok',
      ].join(','),
    );
  }
  return csv.toString();
}

String _table(
  Iterable<BenchmarkResult> results,
  Iterable<Scenario> columns, {
  bool boldFastest = false,
}) {
  final rows = <String, Map<Scenario, BenchmarkResult>>{};
  final fastest = <Scenario, int>{};
  for (final result in results) {
    (rows[result.database] ??= {})[result.scenario] = result;
    if (result.value case final int time when boldFastest) {
      final best = fastest[result.scenario];
      if (best == null || time < best) fastest[result.scenario] = time;
    }
  }

  final headers = columns.map(
    (scenario) => '${scenario.label} (${scenario.displayUnit})',
  );
  final table = StringBuffer()
    ..writeln('| Database | ${headers.join(' | ')} |')
    ..writeln('| --- | ${columns.map((_) => '---:').join(' | ')} |');
  for (final MapEntry(key: name, value: row) in rows.entries) {
    final cells = columns.map((scenario) {
      final result = row[scenario];
      if (result == null) return '—';
      final value = result.displayValue;
      return result.value != null && result.value == fastest[scenario]
          ? '**$value**'
          : value;
    });
    table.writeln('| $name | ${cells.join(' | ')} |');
  }
  return table.toString();
}
