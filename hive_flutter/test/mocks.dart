import 'package:hive_ce/hive_ce.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks(
  [],
  customMocks: [
    MockSpec<BinaryReader>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<BinaryWriter>(onMissingStub: OnMissingStub.returnDefault),
  ],
)
export 'mocks.mocks.dart';
