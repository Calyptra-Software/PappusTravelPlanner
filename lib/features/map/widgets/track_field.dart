import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../track_import_flow.dart';
import '../track_summary.dart';
import 'track_row.dart';

/// The lines an entry actually followed, in the form that edits the entry.
///
/// Offered on an entry that **already exists**, because a track hangs off a row
/// and a form being filled in for a new entry has no row yet. That is the same
/// reason the leg-replacing search is offered only on an existing leg, and it is
/// not a hardship: importing a line is something done about a leg that is
/// already in the plan.
///
/// A **list**, one row per stored line, rather than a count with one button
/// under it. An entry carries several lines routinely — a recording that stopped
/// and started again arrives as one row per `<trkseg>`, a second import adds to
/// what is there, and a connection from the search leaves its computed route
/// beside anything recorded — and the old summary could only say how many there
/// were and offer to delete all of them. So each row says what tells it apart
/// from the others (the name the file gave it, where it came from, how far it
/// runs) and carries the act that applies to it, which is the rule the group
/// band already follows: the unit an act applies to is the unit it is offered
/// on. *Remove all* stays, and only where it means something more than the row's
/// own button — from two lines up.
///
/// Beneath them, wherever the leg has both ends, the **straight segment**
/// between those ends as one more row ([ChordRow]) — the line the map draws when
/// none of the stored ones is, and the one line whose only act is the eye.
///
/// What is still not offered is a way to *type* a line: a track cannot be
/// written, only imported, and the map is where one is looked at.
class TrackField extends ConsumerWidget {
  const TrackField({
    super.key,
    required this.itemId,
    required this.tripId,
    this.from,
    this.to,
    this.chordDisplay = TrackDisplay.auto,
    this.onSetChordDisplay,
    this.onImported,
  });

  final int itemId;

  /// The trip the entry belongs to — the import offers *its* entries, since a
  /// recording rarely stops at one.
  final int tripId;

  /// Called after an import that wrote something, so the form around this can
  /// catch up.
  ///
  /// The import writes coordinates straight to the row — it has to, since it
  /// places the *other* entries' ends in the same transaction. The form editing
  /// this one is then holding the values from before, and saving would write
  /// them back over what the import just set. It happened, and only to the entry
  /// whose form was open, which is exactly the shape of two writers on one row.
  final VoidCallback? onImported;

  /// The leg's ends as the form around this currently holds them — not as the
  /// row does, so a segment appears the moment its second end is placed and
  /// goes when one is removed, before anything is saved.
  final LatLng? from;
  final LatLng? to;

  /// What the entry says about drawing the segment between [from] and [to].
  final TrackDisplay chordDisplay;

  /// Writes [chordDisplay]; the segment's row carries no eye without it.
  final ValueChanged<TrackDisplay>? onSetChordDisplay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tracks =
        ref.watch(itemTrackSummariesProvider(itemId)).value ??
        const <TrackSummary>[];
    final chord = summarizeChord(
      from: from,
      to: to,
      display: chordDisplay,
      tracks: tracks,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.trackSection, style: theme.textTheme.labelLarge),
            ),
            // The count only where the list is long enough for it to be a
            // reading rather than a restatement of what is on screen.
            if (tracks.length > 1)
              Text(
                l10n.trackCount(tracks.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // "None" only when there is not even a segment to list: with both ends
        // placed the segment's own row already says what the map draws.
        if (tracks.isEmpty && chord == null)
          Text(
            l10n.trackNone,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        for (final track in tracks)
          TrackRow(
            track: track,
            onSetDisplay: (display) =>
                ref.read(repositoryProvider).setTrackDisplay(track.id, display),
            onRemove: () => ref.read(repositoryProvider).deleteTrack(track.id),
          ),
        if (chord != null)
          ChordRow(chord: chord, onSetDisplay: onSetChordDisplay),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () async {
                final imported = await startTrackImport(
                  context,
                  ref,
                  tripId: tripId,
                  preselected: [itemId],
                );
                if (imported) onImported?.call();
              },
              icon: const Icon(Icons.timeline),
              label: Text(l10n.trackImport),
            ),
            // One line is removed by its own row; this is only worth a button
            // once it says something that button cannot.
            if (tracks.length > 1)
              TextButton.icon(
                onPressed: () =>
                    ref.read(repositoryProvider).deleteTracksForItem(itemId),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.trackRemoveAll),
              ),
          ],
        ),
      ],
    );
  }
}
