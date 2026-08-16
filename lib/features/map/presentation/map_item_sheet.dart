import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../../itinerary/presentation/item_form_sheet.dart';
import '../../itinerary/widgets/item_times.dart';
import '../../itinerary/widgets/transport_mode.dart';
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
class MapItemSheet extends ConsumerWidget {
  const MapItemSheet({super.key, required this.item});

  final ItineraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isTransport = item.kind == ItemKind.transport;
    final mode = isTransport
        ? ref.watch(transportModesByIdProvider)[item.mode]
        : null;

    final title = isTransport
        ? (item.title ?? mode?.label(l10n) ?? '')
        : (item.title ?? item.location ?? '');
    final position = isTransport
        ? null
        : (item.lat == null || item.lon == null
              ? null
              : LatLng(item.lat!, item.lon!));

    return SafeArea(
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
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.edit_outlined),
                label: Text(isTransport ? l10n.editTransport : l10n.editPlace),
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
