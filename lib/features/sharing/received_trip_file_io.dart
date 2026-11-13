import 'dart:io';
import 'dart:typed_data';

/// Reads the received trip file at [path] and deletes it.
///
/// The copy exists only to carry the bytes from Android into Dart, and with
/// photos inside it runs to tens of megabytes the cache should not keep. It is
/// deleted whether or not it could be read; a failed read rethrows.
Future<Uint8List> takeReceivedTrip(String path) async {
  final file = File(path);
  try {
    return await file.readAsBytes();
  } finally {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone: nothing is left to clean up.
    }
  }
}
