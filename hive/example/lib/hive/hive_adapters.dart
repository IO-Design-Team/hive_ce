import 'package:example/main.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hive_ce/hive_ce.dart';

@GenerateAdapters(
  [AdapterSpec<Person>(), AdapterSpec<Job>()],
  converters: [IListConverter()],
)
part 'hive_adapters.g.dart';

class IListConverter extends HiveConverter<IList, List> {
  const IListConverter();

  @override
  IList fromHive(List value) => IList(value);

  @override
  List toHive(IList object) => object.toList();
}
