import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'gpx.dart';
import 'presentation/track_import_screen.dart';
import 'widgets/track_entry_picker.dart';

/// Importing a recording, from either door.
///
/// One flow, entered from two places, and the door decides only what is ticked
/// when the picker opens: the trip's own menu ticks nothing, a leg's form ticks
/// that leg. Keeping it one flow is what makes the single-leg case get the map
/// as well — which is where an entry that was never given coordinates finally
/// gets them, from the recording's own ends.
/// [readFile] is how the file is obtained, and exists so this can be driven
/// without a file chooser: everything after the picking — the refusals, the
/// question about which entries, the division — is behaviour worth a test, and a
/// native dialog in the middle would put all of it out of reach.
Future<bool> startTrackImport(
  BuildContext context,
  WidgetRef ref, {
  required int tripId,
  List<int> preselected = const [],
  Future<String?> Function()? readFile,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final source = await (readFile ?? _pickGpx)();
  if (source == null || !context.mounted) return false;

  final List<GpxTrack> read;
  try {
    read = parseGpx(source);
  } on FormatException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.trackInvalidFile)));
    return false;
  }
  if (read.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.trackNothingInFile)));
    return false;
  }

  // Read once rather than watched: this is a question asked at a moment, and a
  // stream would keep the picker's list moving under the user's finger.
  final items = await ref.read(repositoryProvider).itemsFor(tripId);
  if (!context.mounted) return false;

  final selection = await showTrackEntryPicker(
    context,
    items: items,
    preselected: preselected,
  );
  if (selection == null || selection.isEmpty || !context.mounted) return false;

  final imported = await importTrackAcrossEntries(
    context,
    lines: [for (final track in read) track.points],
    name: read.map((t) => t.name).nonNulls.firstOrNull,
    selection: selection,
  );
  if (imported != true) return false;
  messenger.showSnackBar(SnackBar(content: Text(l10n.trackImported)));
  return true;
}

/// The file, as text.
Future<String?> _pickGpx() async {
  if (_isDesktop) {
    const typeGroup = XTypeGroup(label: 'GPX', extensions: ['gpx']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    return file == null ? null : await file.readAsString();
  }
  // Read through the picked file rather than off a path, so the one branch works
  // on web and native alike — the same choice the trip import makes.
  final result = await FilePicker.pickFiles();
  final bytes = await result?.files.single.readAsBytes();
  return bytes == null ? null : _utf8OrLatin1(bytes);
}

/// GPX is XML and so is UTF-8 in practice, but a file written by an older device
/// may be Latin-1 — and failing on one accented track name would be a poor
/// reason to refuse a whole recording.
String _utf8OrLatin1(Uint8List bytes) {
  try {
    return const Utf8Decoder().convert(bytes);
  } on FormatException {
    return const Latin1Decoder().convert(bytes);
  }
}

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS);
