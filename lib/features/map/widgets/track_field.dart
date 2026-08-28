import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/distance_format.dart';
import '../../../core/providers.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../track_import_flow.dart';
import '../track_summary.dart';

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
/// What is still not offered is a way to *type* a line: a track cannot be
/// written, only imported, and the map is where one is looked at.
class TrackField extends ConsumerWidget {
  const TrackField({
    super.key,
    required this.itemId,
    required this.tripId,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tracks =
        ref.watch(itemTrackSummariesProvider(itemId)).value ??
        const <TrackSummary>[];

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
        if (tracks.isEmpty)
          Text(
            l10n.trackNone,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final track in tracks)
            _TrackRow(
              track: track,
              onRemove: () =>
                  ref.read(repositoryProvider).deleteTrack(track.id),
            ),
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

/// One stored line: what it is, and the one act that applies to it alone.
///
/// The three facts are joined into a single line rather than stacked, because
/// what a reader is doing here is comparing rows — and two of the three are
/// missing often enough (an unnamed recording, a length that cannot be measured)
/// that a fixed two-line layout would leave holes.
class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track, required this.onRemove});

  final TrackSummary track;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final source = switch (track.source) {
      TrackSource.recorded => l10n.trackSourceRecorded,
      TrackSource.imported => l10n.trackSourceImported,
      TrackSource.routed => l10n.trackSourceRouted,
    };
    final length = track.meters == null
        ? l10n.trackNotDrawable
        : formatDistance(track.meters!);

    return Row(
      children: [
        Icon(
          switch (track.source) {
            // A computed route is the one of the three the map draws
            // differently, so it is the one that reads differently here.
            TrackSource.routed => Icons.alt_route,
            _ => Icons.timeline,
          },
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            [?track.name, source, length].join(' · '),
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: onRemove,
          tooltip: l10n.trackRemove,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }
}
