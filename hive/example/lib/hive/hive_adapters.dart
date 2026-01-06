import 'package:example/main.dart';
import 'package:hive_ce/hive_ce.dart';

@GenerateAdapters([
  AdapterSpec<Person>(),
  AdapterSpec<Job>(),
  // TODO: Waiting on analyzer 9 support
  // AdapterSpec<FreezedPerson>(),
])
part 'hive_adapters.g.dart';
