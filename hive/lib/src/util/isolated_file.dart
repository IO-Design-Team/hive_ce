import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// A class that wraps dart:io [File] operations in an isolate to prevent
/// blocking the main thread during I/O operations.
///
/// This class implements most of the same methods as [File], allowing it to be
/// used as a drop-in replacement in many cases.
class IsolatedFile {
  /// The path of the file.
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

  /// Checks if this file exists through the isolate.
  Future<bool> exists() {
    return _sendOperation<bool>('exists', path);
  }

  /// Deletes this file using an isolate.
  Future<IsolatedFile> delete({bool recursive = false}) async {
    await _sendOperation<void>('delete', path);
    return this;
  }

  // File-specific methods

  /// Creates the file using an isolate.
  Future<IsolatedFile> create({
    bool recursive = false,
    bool exclusive = false,
  }) async {
    await _sendOperation<void>(
      'create',
      _CreateParams(path, recursive, exclusive),
    );
    return this;
  }

  /// Renames the file to a new path using an isolate.
  Future<IsolatedFile> rename(String newPath) async {
    final newFilePath = await _sendOperation<String>(
      'rename',
      _CopyParams(path, newPath),
    );
    return IsolatedFile(newFilePath);
  }

  /// Opens the file for random access operations.
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    return file.open(mode: mode);
  }

  /// Reads the entire file contents as a list of bytes using an isolate.
  Future<Uint8List> readAsBytes() async {
    return _sendOperation<Uint8List>('readAsBytes', path);
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
          case 'readAsBytes':
            result = await File(params as String).readAsBytes();
          case 'exists':
            result = await File(params as String).exists();
          case 'delete':
            await File(params as String).delete();
            result = null;
          case 'create':
            final createParams = params as _CreateParams;
            await File(createParams.path).create(
              recursive: createParams.recursive,
              exclusive: createParams.exclusive,
            );
            result = null;
          case 'rename':
            final renameParams = params as _CopyParams;
            final newFile =
                await File(renameParams.path).rename(renameParams.newPath);
            result = newFile.path;
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
