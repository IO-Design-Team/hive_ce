import 'package:example/main.dart';
import 'package:hive_ce/hive_ce.dart';

@GenerateAdapters([AdapterSpec<Person>(), AdapterSpec<Job>()])
part 'hive_adapters.g.dart';
