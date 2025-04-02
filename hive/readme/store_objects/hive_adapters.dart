import 'package:hive_ce/hive.dart';
import 'person.dart';

@GenerateAdapters([AdapterSpec<Person>()])
part 'hive_adapters.g.dart';
