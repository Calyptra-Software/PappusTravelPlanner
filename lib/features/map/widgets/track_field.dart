import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../gpx.dart';

/// The line an entry actually followed, in the form that edits the entry.
///
/// Offered on an entry that **already exists**, because a track hangs off a row
/// and a form being filled in for a new entry has no row yet. That is the same
/// reason the leg-replacing search is offered only on an existing leg, and it is
/// not a hardship: importing a line is something done about a leg that is
/// already in the plan.
///
/// A reading and two buttons, deliberately: what a track *is* cannot be typed,
/// only imported, and a line the user wants to see is on the map one tap away.
/// Showing the point count would be the kind of number that invites tuning
/// something that has no dial.
class TrackField extends ConsumerWidget {
  const TrackField({super.key, required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tracks = ref.watch(itemTracksProvider(itemId)).value ?? const [];

    // A recording that stopped and started again arrives as several lines under
    // one name, so the name is shown once and the count says the rest.
    final name = tracks.map((t) => t.name).nonNulls.firstOrNull;
    final summary = tracks.isEmpty
        ? l10n.trackNone
        : [
            ?name,
            if (name == null || tracks.length > 1)
              l10n.trackCount(tracks.length),
          ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.trackSection, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _import(context, ref),
              icon: const Icon(Icons.timeline),
              label: Text(l10n.trackImport),
            ),
            if (tracks.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    ref.read(repositoryProvider).deleteTracksForItem(itemId),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.trackRemove),
              ),
          ],
        ),
      ],
    );
  }

  /// Picks a GPX file and stores every line in it.
  ///
  /// The lines are **appended**: a leg can carry the walk out of one station and
  /// the walk into the next, and a second import that silently replaced the
  /// first would lose the one already there. Removing is the explicit button
  /// beside this.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(repositoryProvider);

    final String? source;
    if (_isDesktop) {
      const typeGroup = XTypeGroup(label: 'GPX', extensions: ['gpx']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      source = file == null ? null : await file.readAsString();
    } else {
      // Read through the picked file rather than off a path, so the one branch
      // works on web and native alike — the same choice the trip import makes.
      final result = await FilePicker.pickFiles();
      final bytes = await result?.files.single.readAsBytes();
      source = bytes == null ? null : utf8OrLatin1(bytes);
    }
    if (source == null) return;

    final List<GpxTrack> lines;
    try {
      lines = parseGpx(source);
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.trackInvalidFile)));
      return;
    }
    if (lines.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.trackNothingInFile)));
      return;
    }
    await repository.addTracks(itemId, [
      for (final line in lines) (points: line.points, name: line.name),
    ]);
    messenger.showSnackBar(SnackBar(content: Text(l10n.trackImported)));
  }
}

/// Decodes a picked file as text.
///
/// GPX is XML and so is UTF-8 in practice, but a file written by an older device
/// may be Latin-1 — and failing on one accented track name would be a poor
/// reason to refuse a whole recording. The declaration inside the document is
/// not consulted: the parser is handed a string, and a mis-declared file that
/// decodes cleanly is still a file whose points are readable.
String utf8OrLatin1(Uint8List bytes) {
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
