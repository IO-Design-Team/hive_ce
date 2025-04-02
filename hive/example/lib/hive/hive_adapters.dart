import 'package:example/freezed.dart';
import 'package:example/main.dart';
import 'package:hive_ce/hive.dart';

@GenerateAdapters([
  AdapterSpec<Person>(),
  AdapterSpec<FreezedPerson>(),
])
part 'hive_adapters.g.dart';
