library hive_flutter;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:path/path.dart'
    if (dart.library.js_interop) 'src/stub/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart'
    if (dart.library.js_interop) 'src/stub/path_provider.dart';

export 'package:hive_ce/hive.dart';

part 'src/box_extensions.dart';
part 'src/hive_extensions.dart';
part 'src/watch_box_builder.dart';
