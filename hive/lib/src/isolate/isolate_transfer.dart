import 'dart:isolate';
import 'dart:typed_data';

const _transferThreshold = 65536;

/// Copies [bytes] out of a shared or reused buffer for isolate transfer,
/// using [TransferableTypedData] for large payloads.
///
/// Not part of public API
Object wrapBytes(Uint8List bytes) => bytes.length >= _transferThreshold
    ? TransferableTypedData.fromList([bytes])
    : Uint8List.fromList(bytes);

/// Extracts bytes received from another isolate.
///
/// Not part of public API
Uint8List unwrapBytes(dynamic value) => value is TransferableTypedData
    ? value.materialize().asUint8List()
    : value as Uint8List;
