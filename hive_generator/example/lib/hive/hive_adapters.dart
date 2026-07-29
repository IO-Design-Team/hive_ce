import 'package:hive_ce/hive_ce.dart';
import 'package:meta/meta.dart';

@GenerateAdapters(
  [
    AdapterSpec<ClassSpec1>(),
    AdapterSpec<ClassSpec2>(),
    AdapterSpec<ClassSpec3>(),
    AdapterSpec<ClassSpec4>(),
    AdapterSpec<EnumSpec>(),
    AdapterSpec<ClassSpec5>(),
  ],
  firstTypeId: 50,
  converters: [UriConverter()],
)
part 'hive_adapters.g.dart';

/// Example converter matching json_serializable's JsonConverter pattern
class UriConverter implements HiveConverter<Uri, String> {
  const UriConverter();

  @override
  Uri fromHive(String hive) => Uri.parse(hive);

  @override
  String toHive(Uri object) => object.toString();
}

@immutable
class ClassSpec1 {
  final int value;
  final int value2;

  const ClassSpec1(this.value, this.value2);
}

@immutable
class ClassSpec2 {
  final String value;
  final String value2;
  final Iterable<String> iterable;
  final Set<String> set;
  final List<String> list;

  const ClassSpec2(this.value, this.value2, this.iterable, this.set, this.list);
}

class ClassSpec3 {
  int? value;
}

class ClassSpec4<T extends Object> {}

enum EnumSpec {
  value1,
  value2;

  EnumSpec get getter => EnumSpec.value2;
}

@immutable
class ClassSpec5 {
  final Uri url;
  final Uri? optionalUrl;

  const ClassSpec5(this.url, this.optionalUrl);
}
