import 'package:hive_ce/hive.dart';

class StubIns extends IsolateNameServer {
  @override
  dynamic lookupPortByName(String name) => throw UnimplementedError();

  @override
  bool registerPortWithName(dynamic port, String name) =>
      throw UnimplementedError();

  @override
  bool removePortNameMapping(String name) => throw UnimplementedError();
}
