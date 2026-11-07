import 'dart:io';

import 'package:sembast/sembast_io.dart';
import 'package:storage_benchmark/speed_benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

void main() async {
  final store = intMapStoreFactory.store();

  await runSpeedBenchmarks([
    SpeedTarget(
      name: 'sembast',
      path: 'memory_box.db',
      open: () => databaseFactoryIo.openDatabase('memory_box.db'),
      writeAll: (db, values) async {
        await store.addAll(db as Database, [
          for (final value in values) value.toJson(),
        ]);
      },
      flush: (_) async {
        final file = await File('memory_box.db').open(mode: FileMode.append);
        try {
          await file.flush();
        } finally {
          await file.close();
        }
      },
      close: (db) => (db as Database).close(),
      readAll: (db) async => [
        for (final record in await store.find(db as Database))
          TestModel.fromJson(record.value),
      ],
    ),
  ]);
}
