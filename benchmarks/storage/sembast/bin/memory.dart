import 'package:sembast/sembast_io.dart';
import 'package:storage_benchmark/memory_benchmark.dart';
import 'package:storage_benchmark/test_model.dart';

void main(List<String> args) async {
  final store = intMapStoreFactory.store();

  await runMemoryBenchmarks(args, [
    MemoryTarget(
      name: 'sembast',
      path: 'memory_box.db',
      write: (values) async {
        final db = await databaseFactoryIo.openDatabase('memory_box.db');
        await store.addAll(db, [for (final value in values) value.toJson()]);
        await db.close();
      },
      open: () => databaseFactoryIo.openDatabase('memory_box.db'),
      readAll: (db) async => [
        for (final record in await store.find(db as Database))
          TestModel.fromJson(record.value),
      ],
    ),
  ]);
}
