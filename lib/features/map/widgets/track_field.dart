import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../track_import_flow.dart';

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
  const TrackField({super.key, required this.itemId, required this.tripId});

  final int itemId;

  /// The trip the entry belongs to — the import offers *its* entries, since a
  /// recording rarely stops at one.
  final int tripId;

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
              onPressed: () => startTrackImport(
                context,
                ref,
                tripId: tripId,
                preselected: [itemId],
              ),
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
}
