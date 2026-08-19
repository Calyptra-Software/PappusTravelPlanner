import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/accent_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/application/trip_providers.dart';

/// Picks the color one itinerary entry is drawn in **on the map** — the line
/// of a leg or the pin of a place — or leaves it to the trip's own accent.
///
/// One widget for the two places the choice is offered, because it is one
/// choice: the entry's form, where everything else about it is set, and the
/// sheet a marker opens, where the color is the thing being looked at. A
/// second copy is how the two quietly grow different defaults.
///
/// The "trip color" swatch shows the accent it would actually fall back to,
/// which is the only honest way to draw *no choice*: an empty slot would say
/// the entry has no color, when in fact it has the trip's.
class ItemColorField extends ConsumerWidget {
  const ItemColorField({
    super.key,
    required this.tripId,
    required this.value,
    required this.onChanged,
  });

  final int tripId;

  /// The entry's own color as ARGB, or null for the trip's accent.
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final trip = ref.watch(tripProvider(tripId)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.mapColor, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          l10n.mapColorHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AccentPicker(
          selected: value,
          onSelected: onChanged,
          // Null while the trip is still loading — the swatch then draws as the
          // neutral dot rather than guessing an accent, and still selects the
          // same state.
          inherited: trip == null ? null : Color(trip.colorValue),
          inheritTooltip: l10n.mapColorTrip,
          onInherit: () => onChanged(null),
        ),
      ],
    );
  }
}
