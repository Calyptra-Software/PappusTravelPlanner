import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Android side: `DocumentOpener.kt`, which turns the path into a
/// `content://` URI of the app's own `FileProvider` and starts `ACTION_VIEW`.
const MethodChannel _android = MethodChannel(
  'dev.calyptra.pappus/open_document',
);

/// Writes [bytes] to the app's cache as [fileName] and asks the platform to
/// open that file, answering whether something took it.
///
/// `false` means nothing will show it: no program for this type, a platform
/// that cannot be asked (iOS, whose sandbox a file URL does not leave), or a
/// type too vague to hand anywhere. The caller then offers the share sheet,
/// which is the way that always works.
///
/// **Where the copy goes.** `<cache>/opened/<slot>/<fileName>`, the app's own
/// cache directory — per application id, so the side-by-side CI build keeps
/// its own — and never a shared temporary directory, where a passport scan
/// would be readable by every account on a desktop. The file keeps its name
/// because the viewer shows it and a desktop picks the program by its
/// extension. [slot] (the attachment's id) keeps two files of the same name
/// apart.
///
/// **How long it stays.** Until the next file is opened: everything under
/// `opened/` is removed first, so at most one document lies outside the
/// database at a time. It cannot be removed *after* opening, since the viewer
/// reads it after this returns — a PDF viewer page by page, for as long as it
/// is open. On Windows a file a viewer still holds cannot be deleted or
/// rewritten; the copy already there is then used, the bytes of an attachment
/// never changing once stored.
Future<bool> openBytesExternally({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  required String slot,
}) async {
  final supported =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS;
  if (!supported) return false;

  final opened = Directory(
    p.join((await getApplicationCacheDirectory()).path, 'opened'),
  );
  await _clear(opened);
  final file = File(p.join(opened.path, slot, fileName));
  try {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  } on FileSystemException {
    // Held open by the viewer it was handed to last time (Windows); the same
    // bytes are already there.
    if (!await file.exists() || await file.length() != bytes.length) {
      rethrow;
    }
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    final opened = await _android.invokeMethod<bool>('open', {
      'path': file.path,
      'mimeType': mimeType,
    });
    return opened ?? false;
  }
  return launchUrl(Uri.file(file.path));
}

/// Removes what earlier opens left behind, as far as it can: a file a viewer
/// still holds stays, and is simply cleared next time.
Future<void> _clear(Directory opened) async {
  if (!await opened.exists()) return;
  await for (final entry in opened.list()) {
    try {
      await entry.delete(recursive: true);
    } on FileSystemException {
      // Still open somewhere.
    }
  }
}
