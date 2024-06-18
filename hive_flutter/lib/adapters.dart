library hive_flutter_adapters;

import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:hive_ce/hive.dart' show TypeAdapter, BinaryReader, BinaryWriter;

export 'hive_flutter.dart';

part 'src/adapters/color_adapter.dart';
part 'src/adapters/time_adapter.dart';
