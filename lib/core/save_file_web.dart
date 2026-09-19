import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// How long the object URL is kept alive after the download was started.
///
/// It has to be freed: the blob holds a whole copy of the database in the
/// browser's memory, and a page that exports twice would otherwise hold two.
/// It must not be freed *immediately*, though — the browser reads the blob
/// after the click returns, and revoking the URL before it has is one of the
/// two ways this download goes missing (see [saveBytesToFile]). A minute is
/// far longer than the read takes and far shorter than a session.
const Duration _keepObjectUrl = Duration(minutes: 1);

/// Hands [bytes] to the browser as a download named [fileName], and answers
/// that they were handed over.
///
/// Always `true`, and that is the honest answer rather than a stub: what
/// happens next belongs to the browser. There is no dialog to wait for, no
/// path to come back, and a download the user then declines or deletes is not
/// something a page is told about. So the caller may say "exported" — the app
/// has done everything it can do.
///
/// Deliberately not `FilePicker.saveFile`, which does the same dance and then
/// loses the download in two ways its own docstring does not mention:
///
/// * it never appends the anchor to the document, and Firefox does not act on
///   a click on an element that is not in the page;
/// * it revokes the object URL in the same turn as the click, before the
///   browser has read the blob.
///
/// Its web implementation also returns `null` whether it worked or not, so no
/// caller of it can distinguish a save from a cancellation — which is why the
/// native side of this pair answers a `bool` rather than passing the `Uri` on.
Future<bool> saveBytesToFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  String? dialogTitle,
}) async {
  // `dialogTitle` has nowhere to go: the browser's download has no dialog of
  // ours to put a title on.
  final host = web.document.body ?? web.document.documentElement;
  if (host == null) return false;

  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;

  host.appendChild(anchor);
  anchor.click();
  anchor.remove();
  Timer(_keepObjectUrl, () => web.URL.revokeObjectURL(url));
  return true;
}
