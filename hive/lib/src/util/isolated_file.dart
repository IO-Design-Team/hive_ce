import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// A class that wraps dart:io [File] operations in an isolate to prevent
/// blocking the main thread during I/O operations.
///
/// This class implements most of the same methods as [File], allowing it to be
/// used as a drop-in replacement in many cases.
class IsolatedFile implements FileSystemEntity {
  /// The path of the file.
  @override
  final String path;

  // Isolate infrastructure
  static Isolate? _isolate;
  static SendPort? _sendPort;
  static final ReceivePort _receivePort = ReceivePort();
  static final Map<int, Completer<dynamic>> _completers = {};
  static int _nextOperationId = 0;
  static final _isolateStartCompleter = Completer<void>();
  static bool _isInitializing = false;

  /// Creates a new [IsolatedFile] with the given [path].
  const IsolatedFile(this.path);

  /// Creates a new [IsolatedFile] from a [File] object.
  factory IsolatedFile.fromFile(File file) => IsolatedFile(file.path);

  /// Returns a [File] object that corresponds to the same file as this
  /// [IsolatedFile].
  File get file => File(path);

  /// Returns whether this object's path is absolute.
  @override
  bool get isAbsolute => file.isAbsolute;

  /// The URI of this file.
  @override
  Uri get uri => file.uri;

  /// A [Stream] of [FileSystemEvent]s for this file.
  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    // Watch operations need to happen on the main isolate to properly stream events
    return file.watch(events: events, recursive: recursive);
  }

  /// Gets the file path of the file when [path] is a link.
  @override
  Future<String> resolveSymbolicLinks() {
    return _sendOperation<String>('resolveSymbolicLinks', path);
  }

  /// Synchronous version of [resolveSymbolicLinks] - not recommended.
  ///
  /// Note: This will run on the main thread since it's synchronous.
  @override
  String resolveSymbolicLinksSync() {
    return file.resolveSymbolicLinksSync();
  }

  /// Checks if this file exists through the isolate.
  @override
  Future<bool> exists() {
    return _sendOperation<bool>('exists', path);
  }

  /// Synchronous check if file exists - not recommended.
  ///
  /// Note: This will run on the main thread since it's synchronous.
  /// It's recommended to use [exists] instead if possible.
  @override
  bool existsSync() {
    return file.existsSync();
  }

  /// Returns a [FileStat] object for this file.
  @override
  Future<FileStat> stat() {
    return _sendOperation<FileStat>('stat', path);
  }

  /// Synchronous version of [stat] - not recommended.
  ///
  /// Note: This will run on the main thread since it's synchronous.
  @override
  FileStat statSync() {
    return file.statSync();
  }

  /// Gets the parent directory of this file.
  @override
  Directory get parent => Directory(dirname(path));

  /// Creates a [IsolatedFile] instance whose path is the absolute path of [path].
  @override
  IsolatedFile get absolute => IsolatedFile(file.absolute.path);

  /// Deletes this file using an isolate.
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    await _sendOperation<void>('delete', path);
    return this;
  }

  /// Synchronous delete operation - not recommended.
  ///
  /// Note: This will run on the main thread since it's synchronous.
  /// It's recommended to use [delete] instead if possible.
  @override
  void deleteSync({bool recursive = false}) {
    file.deleteSync(recursive: recursive);
  }

  /// Renames this file synchronously - not recommended.
  ///
  /// Note: This will run on the main thread since it's synchronous.
  /// It's recommended to use [rename] instead if possible.
  @override
  FileSystemEntity renameSync(String newPath) {
    file.renameSync(newPath);
    return IsolatedFile(newPath);
  }

  // File-specific methods

  /// Creates the file using an isolate.
  Future<IsolatedFile> create(
      {bool recursive = false, bool exclusive = false}) async {
    await _sendOperation<void>(
        'create', _CreateParams(path, recursive, exclusive));
    return this;
  }

  /// Copies the file to a new path using an isolate.
  Future<IsolatedFile> copy(String newPath) async {
    final newFilePath = await _sendOperation<String>(
      'copy',
      _CopyParams(path, newPath),
    );
    return IsolatedFile(newFilePath);
  }

  /// Renames the file to a new path using an isolate.
  Future<IsolatedFile> rename(String newPath) async {
    final newFilePath = await _sendOperation<String>(
      'rename',
      _CopyParams(path, newPath),
    );
    return IsolatedFile(newFilePath);
  }

  /// Returns the length of the file in bytes using an isolate.
  Future<int> length() async {
    return _sendOperation<int>('length', path);
  }

  /// Gets the last-modified time for the file using an isolate.
  Future<DateTime> lastModified() async {
    return _sendOperation<DateTime>('lastModified', path);
  }

  /// Sets the last-modified time for the file using an isolate.
  Future<IsolatedFile> setLastModified(DateTime time) async {
    await _sendOperation<void>(
        'setLastModified', _LastModifiedParams(path, time));
    return this;
  }

  /// Opens the file for random access operations.
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    return file.open(mode: mode);
  }

  /// Reads the entire file contents as a string using an isolate.
  Future<String> readAsString({Encoding encoding = utf8}) async {
    return _sendOperation<String>('readAsString', _FileParams(path, encoding));
  }

  /// Reads the entire file contents as a list of bytes using an isolate.
  Future<Uint8List> readAsBytes() async {
    return _sendOperation<Uint8List>('readAsBytes', path);
  }

  /// Reads the entire file contents as a list of lines using an isolate.
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async {
    return _sendOperation<List<String>>(
        'readAsLines', _FileParams(path, encoding));
  }

  /// Writes a string to the file using an isolate.
  Future<void> writeAsString(
    String contents, {
    Encoding encoding = utf8,
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    return _sendOperation<void>(
      'writeAsString',
      _WriteParams(
        path,
        contents,
        encoding,
        mode,
        flush,
      ),
    );
  }

  /// Writes a list of bytes to the file using an isolate.
  Future<void> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    return _sendOperation<void>(
      'writeAsBytes',
      _ByteWriteParams(
        path,
        bytes,
        mode,
        flush,
      ),
    );
  }

  /// Initializes the isolate if not already initialized
  static Future<void> _ensureInitialized() async {
    if (_isolate != null) {
      return _isolateStartCompleter.future;
    }

    if (_isInitializing) {
      return _isolateStartCompleter.future;
    }

    _isInitializing = true;

    try {
      // Set up the receive port listener
      _receivePort.listen((message) {
        if (message is SendPort) {
          // This is the initial handshake - store the port
          _sendPort = message;
          _isolateStartCompleter.complete();
          return;
        }

        if (message is! Map) return;

        final id = message['id'] as int?;
        if (id == null || !_completers.containsKey(id)) return;

        final completer = _completers[id]!;

        if (message.containsKey('error')) {
          completer.completeError(message['error']);
        } else {
          completer.complete(message['result']);
        }

        _completers.remove(id);
      });

      // Start the isolate
      _isolate = await Isolate.spawn(
        _isolateMain,
        _receivePort.sendPort,
      );
    } catch (e) {
      _isInitializing = false;
      _isolateStartCompleter.completeError(e);
      rethrow;
    }

    return _isolateStartCompleter.future;
  }

  /// Sends a message to the file operations isolate and returns the result
  static Future<T> _sendOperation<T>(String operation, dynamic params) async {
    await _ensureInitialized();

    final operationId = _nextOperationId++;
    final completer = Completer<T>();
    _completers[operationId] = completer;

    _sendPort!.send({
      'id': operationId,
      'operation': operation,
      'params': params,
    });

    return completer.future;
  }

  /// Shuts down the isolate. Call this when you no longer need file operations.
  static Future<void> shutdown() async {
    if (_isolate != null) {
      _isolate?.kill();
      _isolate = null;
      _sendPort = null;
      _completers.clear();
      _receivePort.close();
    }
  }

  /// The main entry point for the file operations isolate
  static void _isolateMain(SendPort sendPort) {
    final receivePort = ReceivePort();

    // Send back a SendPort for communication
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is! Map) return;

      final id = message['id'] as int?;
      final operation = message['operation'] as String?;
      final params = message['params'];

      if (id == null || operation == null) return;

      try {
        dynamic result;

        switch (operation) {
          case 'readAsString':
            result = await _readAsString(params as _FileParams);
            break;
          case 'readAsBytes':
            result = await _readAsBytes(params as String);
            break;
          case 'readAsLines':
            result = await _readAsLines(params as _FileParams);
            break;
          case 'writeAsString':
            await _writeAsString(params as _WriteParams);
            result = null;
            break;
          case 'writeAsBytes':
            await _writeAsBytes(params as _ByteWriteParams);
            result = null;
            break;
          case 'exists':
            result = await _exists(params as String);
            break;
          case 'delete':
            await _delete(params as String);
            result = null;
            break;
          case 'create':
            await _create(params as _CreateParams);
            result = null;
            break;
          case 'copy':
            result = await _copy(params as _CopyParams);
            break;
          case 'rename':
            result = await _rename(params as _CopyParams);
            break;
          case 'length':
            result = await _length(params as String);
            break;
          case 'lastModified':
            result = await _lastModified(params as String);
            break;
          case 'setLastModified':
            await _setLastModified(params as _LastModifiedParams);
            result = null;
            break;
          case 'resolveSymbolicLinks':
            result = await _resolveSymbolicLinks(params as String);
            break;
          case 'stat':
            result = await _stat(params as String);
            break;
          default:
            throw Exception('Unknown operation: $operation');
        }

        sendPort.send({
          'id': id,
          'result': result,
        });
      } catch (e) {
        sendPort.send({
          'id': id,
          'error': e.toString(),
        });
      }
    });
  }

  // Returns the directory name for a file path
  static String dirname(String path) {
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    if (lastSeparator == -1) return '.';

    if (lastSeparator == 0) return Platform.pathSeparator;

    return path.substring(0, lastSeparator);
  }
}

/// Internal class for file operation parameters.
class _FileParams {
  final String path;
  final Encoding encoding;

  _FileParams(this.path, this.encoding);
}

/// Internal class for write operation parameters.
class _WriteParams extends _FileParams {
  final String contents;
  final FileMode mode;
  final bool flush;

  _WriteParams(
    String path,
    this.contents,
    Encoding encoding,
    this.mode,
    this.flush,
  ) : super(path, encoding);
}

/// Internal class for byte write operation parameters.
class _ByteWriteParams {
  final String path;
  final List<int> bytes;
  final FileMode mode;
  final bool flush;

  _ByteWriteParams(this.path, this.bytes, this.mode, this.flush);
}

/// Internal class for create operation parameters.
class _CreateParams {
  final String path;
  final bool recursive;
  final bool exclusive;

  _CreateParams(this.path, this.recursive, this.exclusive);
}

/// Internal class for copy operation parameters.
class _CopyParams {
  final String path;
  final String newPath;

  _CopyParams(this.path, this.newPath);
}

/// Internal class for last modified parameters.
class _LastModifiedParams {
  final String path;
  final DateTime time;

  _LastModifiedParams(this.path, this.time);
}

// Isolate worker functions
Future<String> _readAsString(_FileParams params) async {
  return File(params.path).readAsString(encoding: params.encoding);
}

Future<Uint8List> _readAsBytes(String path) async {
  return File(path).readAsBytes();
}

Future<List<String>> _readAsLines(_FileParams params) async {
  return File(params.path).readAsLines(encoding: params.encoding);
}

Future<void> _writeAsString(_WriteParams params) async {
  final file = File(params.path);
  await file.writeAsString(
    params.contents,
    encoding: params.encoding,
    mode: params.mode,
    flush: params.flush,
  );
}

Future<void> _writeAsBytes(_ByteWriteParams params) async {
  final file = File(params.path);
  await file.writeAsBytes(
    params.bytes,
    mode: params.mode,
    flush: params.flush,
  );
}

Future<bool> _exists(String path) async {
  return File(path).exists();
}

Future<void> _delete(String path) async {
  await File(path).delete();
}

Future<void> _create(_CreateParams params) async {
  await File(params.path)
      .create(recursive: params.recursive, exclusive: params.exclusive);
}

Future<String> _copy(_CopyParams params) async {
  final newFile = await File(params.path).copy(params.newPath);
  return newFile.path;
}

Future<String> _rename(_CopyParams params) async {
  final newFile = await File(params.path).rename(params.newPath);
  return newFile.path;
}

Future<int> _length(String path) async {
  return File(path).length();
}

Future<DateTime> _lastModified(String path) async {
  return File(path).lastModified();
}

Future<void> _setLastModified(_LastModifiedParams params) async {
  await File(params.path).setLastModified(params.time);
}

Future<String> _resolveSymbolicLinks(String path) async {
  return File(path).resolveSymbolicLinks();
}

Future<FileStat> _stat(String path) async {
  return File(path).stat();
}
