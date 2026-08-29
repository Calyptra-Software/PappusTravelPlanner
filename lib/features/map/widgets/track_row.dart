import 'package:flutter/material.dart';

import '../../../core/format/distance_format.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../track_summary.dart';

/// One stored line, as both places that list one read it.
///
/// Shared by the item form — where each row carries the act that applies to it
/// alone — and the sheet a tapped line opens on the map, which is a reading and
/// passes no [onRemove]. One widget rather than two, so the words that tell two
/// lines apart cannot come out differently depending on which screen is asking.
///
/// The three facts are joined into a single line rather than stacked, because
/// what a reader is doing here is comparing rows — and two of the three are
/// missing often enough (an unnamed recording, a length that cannot be measured)
/// that a fixed two-line layout would leave holes.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    this.onRemove,
    this.highlighted = false,
  });

  final TrackSummary track;

  /// Removes this line, where removing one is something the screen offers. Null
  /// on a reading, which is not the place an act lives.
  final VoidCallback? onRemove;

  /// Marks this row as the line that was just tapped on the map.
  ///
  /// A tint and nothing else: the tap is what put the sheet on screen, so the
  /// connection between the finger and the marked row is immediate, and a
  /// caption saying "this one" would be a label over something already legible.
  final bool highlighted;

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

    return Container(
      decoration: highlighted
          ? BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: EdgeInsets.symmetric(horizontal: highlighted ? 8 : 0),
      child: Row(
        children: [
          Icon(
            switch (track.source) {
              // A computed route is the one of the three the map draws
              // differently, so it is the one that reads differently here.
              TrackSource.routed => Icons.alt_route,
              _ => Icons.timeline,
            },
            size: 18,
            color: highlighted
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [?track.name, source, length].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: highlighted
                    ? theme.colorScheme.onSecondaryContainer
                    : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: l10n.trackRemove,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}
