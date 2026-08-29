import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../../itinerary/presentation/item_form_sheet.dart';
import '../../itinerary/widgets/item_times.dart';
import '../../itinerary/widgets/transport_mode.dart';
import '../track_summary.dart';
import '../widgets/item_color_field.dart';
import '../widgets/track_row.dart';
import 'map_picker_screen.dart';

/// What a marker stands for, opened by tapping it.
///
/// A map can only say *where*. The name, the times, how late the leg ran, the
/// note someone left on it — all of that lives in the row the marker was drawn
/// from, and a pin with no way to ask about it is a dot on a picture.
///
/// Deliberately a **reading**, not a second editor: the times are rendered by
/// the same `ItemTimes` the timeline uses, so a delay reads identically in both
/// places, and changing anything is one tap further on, in the form that already
/// owns that job.
///
/// The **color** is the one exception, and it is the exception that states the
/// rule: it is the single property of an entry that says nothing about the plan
/// and everything about how it is drawn *here*. Picking it anywhere else means
/// choosing a color against a map you cannot see — which line was hard to
/// follow, which two run together — so it is set where that is answered, and the
/// map redraws under the sheet as it is chosen.
class MapItemSheet extends ConsumerWidget {
  const MapItemSheet({super.key, required this.item, this.highlightTrackId});

  final ItineraryItem item;

  /// The stored line the tap landed on, when it landed on one rather than on a
  /// marker.
  ///
  /// A leg draws one line per stored track, so "which entry is this" was only
  /// half the question a tap asks — the other half is which of that entry's
  /// lines, and the answer cannot be given on the map itself, where every line
  /// of an entry is the same color by design. So the sheet lists them and marks
  /// the one that was tapped. Null when a marker was tapped, or when the line is
  /// the straight segment between the ends, which is a drawing of the plan and
  /// not a row to point at.
  final int? highlightTrackId;

  /// Writes the entry's map color, and nothing else.
  ///
  /// Through a targeted update rather than `updateItem`, which replaces the
  /// whole row: the sheet holds the entry as it was when the marker was tapped,
  /// and a full replace would undo anything that changed since — a live-times
  /// refresh on the leg being exactly the kind of thing that does.
  Future<void> _setColor(WidgetRef ref, int? colorValue) =>
      ref.read(repositoryProvider).setItemColor(item.id, colorValue);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isTransport = item.kind == ItemKind.transport;
    // The color as the *database* holds it, not as the tapped marker did: it is
    // the one thing this sheet writes, so it is the one thing that has to be
    // read live — a swatch that stays on the old color after being picked looks
    // like the tap missed. Everything else is a reading of the row as it was.
    //
    // The row itself, not its color, is what falls back to the tapped one:
    // "cleared" is a color of null, and reading it through a `??` would hand
    // the stale color straight back.
    final live = ref
        .watch(itineraryProvider(item.tripId))
        .value
        ?.where((i) => i.id == item.id)
        .firstOrNull;
    final colorValue = (live ?? item).colorValue;
    final mode = isTransport
        ? ref.watch(transportModesByIdProvider)[item.mode]
        : null;
    // The lines this entry carries, read the same way the form reads them. A
    // *reading*, like the times above it: removing one is an act, and acts live
    // in the form the button below opens. What this answers is the question the
    // tap asked — which of these lines is the one under my finger.
    final tracks = isTransport
        ? (ref.watch(itemTrackSummariesProvider(item.id)).value ??
              const <TrackSummary>[])
        : const <TrackSummary>[];

    final title = isTransport
        ? (item.title ?? mode?.label(l10n) ?? '')
        : (item.title ?? item.location ?? '');
    final position = isTransport
        ? null
        : (item.lat == null || item.lon == null
              ? null
              : LatLng(item.lat!, item.lon!));

    return SafeArea(
      // Scrollable, because what the sheet has to say is not a fixed height: a
      // leg with both ends placed, a note on it and the color row is already
      // taller than a bottom sheet on a phone in landscape, and content that
      // cannot be reached is content that is not there.
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isTransport
                        ? (mode?.icon ?? kDefaultTransportModeIcon)
                        : Icons.place_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title.isEmpty ? l10n.coordinatesNone : title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              if (isTransport &&
                  (item.fromLocation != null || item.toLocation != null)) ...[
                const SizedBox(height: 8),
                Text(
                  '${item.fromLocation ?? '?'} → ${item.toLocation ?? '?'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              ItemTimes(item: item),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.notes!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              // The numbers behind the mark. A coordinate cannot be checked
              // against the map by eye, so the sheet prints what the entry
              // actually holds rather than leaving it implied by the pin.
              for (final line in _positions(l10n, position))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (tracks.isNotEmpty) ...[
                Text(l10n.trackSection, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                for (final track in tracks)
                  TrackRow(
                    track: track,
                    highlighted: track.id == highlightTrackId,
                  ),
                const SizedBox(height: 12),
              ],
              // The one control here, for the one property that is about this
              // screen. Written as it is picked — there is nothing to confirm,
              // and the map behind redraws to show what was chosen.
              ItemColorField(
                tripId: item.tripId,
                value: colorValue,
                onChanged: (value) => _setColor(ref, value),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    isTransport ? l10n.editTransport : l10n.editPlace,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showItemFormSheet(
                      context,
                      tripId: item.tripId,
                      kind: item.kind,
                      existing: item,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The coordinate lines: one for a place, one per end for a leg — labeled, so
  /// two numbers under each other cannot be mistaken for one another.
  List<String> _positions(AppLocalizations l10n, LatLng? place) {
    if (place != null) {
      return ['${l10n.coordinatesLabel}: ${formatCoordinates(place)}'];
    }
    return [
      if (item.fromLat != null && item.fromLon != null)
        '${l10n.coordinatesFrom}: '
            '${formatCoordinates(LatLng(item.fromLat!, item.fromLon!))}',
      if (item.toLat != null && item.toLon != null)
        '${l10n.coordinatesTo}: '
            '${formatCoordinates(LatLng(item.toLat!, item.toLon!))}',
    ];
  }
}
