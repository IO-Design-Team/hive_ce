import 'dart:collection';

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
  converters: [UriConverter(), UnmodifiableListViewConverter<String>()],
)
part 'hive_adapters.g.dart';

class UriConverter extends HiveConverter<Uri, String> {
  const UriConverter();

  @override
  Uri fromHive(String value) => Uri.parse(value);

  @override
  String toHive(Uri value) => value.toString();
}

class UnmodifiableListViewConverter<E>
    extends HiveConverter<UnmodifiableListView<E>, List<E>> {
  const UnmodifiableListViewConverter();

  @override
  UnmodifiableListView<E> fromHive(List<E> value) =>
      UnmodifiableListView(value);

  @override
  List<E> toHive(UnmodifiableListView<E> value) => value.toList();
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
  final Uri uri;
  final Uri? nullableUri;
  final UnmodifiableListView<String> list;

  const ClassSpec5(this.uri, this.nullableUri, this.list);
}
