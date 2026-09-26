import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// How long the tab's object URL stays valid.
///
/// Longer than the download's minute in `save_file_web.dart`, because here the
/// blob is not read once and done with: a browser's PDF viewer goes back to it
/// for its own *Download* and *Print* buttons. Still freed eventually, since
/// every open holds a copy of the file in the page's memory.
const Duration _keepObjectUrl = Duration(minutes: 10);

/// Opens [bytes] in a new browser tab, answering whether one opened.
///
/// A browser shows a PDF, a picture or text itself and downloads anything else,
/// which is the browser's version of "the program that opens this kind of
/// file". `false` is a blocked pop-up: the tap that asked for it may have gone
/// stale while the bytes were read. [fileName] and [slot] have nowhere to go —
/// a blob URL carries no name, and nothing is written anywhere.
Future<bool> openBytesExternally({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  required String slot,
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final tab = web.window.open(url, '_blank');
  if (tab == null) {
    web.URL.revokeObjectURL(url);
    return false;
  }
  Timer(_keepObjectUrl, () => web.URL.revokeObjectURL(url));
  return true;
}
