import 'package:example/freezed.dart';
import 'package:example/main.dart';
import 'package:hive_ce/hive.dart';

part 'hive_adapters.g.dart';

@GenerateAdapters([
  AdapterSpec<Person>(),
  AdapterSpec<FreezedPerson>(),
])
// This is for code generation
// ignore: unused_element
void _() {}
