library hive_flutter.test.mocks;

import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';

export 'mocks.mocks.dart';

@GenerateMocks([], customMocks: [
  MockSpec<BinaryReader>(onMissingStub: OnMissingStub.returnDefault),
  MockSpec<BinaryWriter>(onMissingStub: OnMissingStub.returnDefault),
])
// ignore: prefer_typing_uninitialized_variables, unused_element
var _mocks;
