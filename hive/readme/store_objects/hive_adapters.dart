import 'package:hive_ce/hive.dart';
import 'person.dart';

part 'hive_adapters.g.dart';

@GenerateAdapters([AdapterSpec<Person>()])
// Annotations must be on some element
// ignore: unused_element
void _() {}
