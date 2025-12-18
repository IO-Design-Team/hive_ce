import 'package:hive_ce/src/hive.dart';
import 'package:hive_ce/src/hive_impl.dart';

import 'package:hive_ce/src/isolate/isolated_hive.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/isolated_hive_impl.dart';
import 'package:hive_ce/src/util/logger.dart';

export 'src/box_collection/box_collection_stub.dart'
    if (dart.library.js_interop) 'package:hive_ce/src/box_collection/box_collection_indexed_db.dart'
    if (dart.library.io) 'package:hive_ce/src/box_collection/box_collection.dart';
export 'src/object/hive_object.dart' show HiveObject, HiveObjectMixin;

export 'src/annotations/generate_adapters.dart';
export 'src/annotations/hive_field.dart';
export 'src/annotations/hive_type.dart';
export 'src/binary/binary_reader.dart';
export 'src/binary/binary_writer.dart';
export 'src/box/box.dart';
export 'src/box/box_base.dart';
export 'src/box/lazy_box.dart';
export 'src/crypto/hive_aes_cipher.dart';
export 'src/crypto/hive_cipher.dart';
export 'src/hive.dart';
export 'src/hive_error.dart';
export 'src/object/hive_collection.dart';
export 'src/object/hive_list.dart';
export 'src/object/hive_storage_backend_preference.dart';
export 'src/registry/type_adapter.dart';
export 'src/registry/type_registry.dart';

export 'src/isolate/isolate_name_server.dart';
export 'src/isolate/isolated_hive.dart';
export 'src/isolate/isolated_box.dart';

/// Global constant to access [Hive]
// ignore: non_constant_identifier_names
final HiveInterface Hive = HiveImpl();

/// Global constant to access [IsolatedHive]
///
/// [IsolatedHive] delegates method calls to an isolate. This allows safe
/// usage of Hive across multiple isolates.
///
/// Limitations:
/// - On web, [IsolatedHive] directly calls [Hive] since web does not support
///   isolates
/// - [IsolatedHive] does not support [HiveObject] or [HiveList]
/// - Most methods are async due to isolate communication
// ignore: non_constant_identifier_names
final IsolatedHiveInterface IsolatedHive = IsolatedHiveImpl();

/// Hive's logger
typedef HiveLogger = Logger;

/// Hive's logger level
typedef HiveLoggerLevel = LoggerLevel;
