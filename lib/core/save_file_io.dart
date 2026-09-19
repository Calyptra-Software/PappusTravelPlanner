import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Asks where [bytes] should go and writes them there, answering whether a
/// file was written.
///
/// `false` is a cancellation: the user closed the dialog, or Android's document
/// picker came back with nothing. The caller says nothing in that case, because
/// nothing happened.
Future<bool> saveBytesToFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  String? dialogTitle,
}) async {
  final saved = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
  return saved != null;
}
