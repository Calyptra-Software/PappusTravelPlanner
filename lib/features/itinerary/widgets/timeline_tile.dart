import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/presentation/cost_chip.dart';
import 'transport_mode.dart';

/// A single row in the itinerary timeline. Renders as a place stop or, for
/// transport items, as a lighter connector between stops.
class TimelineTile extends StatelessWidget {
  const TimelineTile({
    super.key,
    required this.item,
    required this.accent,
    required this.onTap,
    required this.costs,
    required this.localeName,
    required this.onTapCost,
    this.group,
    this.isFirstInGroup = false,
    this.isLastInGroup = false,
    this.groupCosts = const [],
    this.dragHandle,
  });

  final ItineraryItem item;
  final Color accent;
  final VoidCallback onTap;
  final List<Cost> costs;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  /// The item's group, or null when it stands alone. When set, the tile is part
  /// of a contiguous group run: [isFirstInGroup] / [isLastInGroup] mark its ends.
  final ItemGroup? group;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  /// The group's shared costs, rendered once under the run's last member.
  final List<Cost> groupCosts;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final costsSection = _CostsSection(
      costs: costs,
      localeName: localeName,
      onTapCost: onTapCost,
    );
    final row = item.kind == ItemKind.transport
        ? _TransportRow(
            item: item,
            onTap: onTap,
            dragHandle: dragHandle,
            costsSection: costsSection,
          )
        : _PlaceRow(
            item: item,
            accent: accent,
            onTap: onTap,
            dragHandle: dragHandle,
            costsSection: costsSection,
          );

    if (group == null) return row;
    return _GroupBand(
      accent: accent,
      isFirst: isFirstInGroup,
      isLast: isLastInGroup,
      label: group!.label,
      groupCosts: groupCosts,
      localeName: localeName,
      onTapCost: onTapCost,
      child: row,
    );
  }
}

/// Wraps a grouped item's row, bracketing a contiguous run with the group's
/// label above its first member and its shared costs below its last. A tinted
/// left rail and background make the run read as one unit (e.g. a train journey
/// on a single ticket).
class _GroupBand extends StatelessWidget {
  const _GroupBand({
    required this.accent,
    required this.isFirst,
    required this.isLast,
    required this.label,
    required this.groupCosts,
    required this.localeName,
    required this.onTapCost,
    required this.child,
  });

  final Color accent;
  final bool isFirst;
  final bool isLast;
  final String? label;
  final List<Cost> groupCosts;
  final String localeName;
  final ValueChanged<Cost> onTapCost;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final radius = const Radius.circular(12);
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? radius : Radius.zero,
          topRight: isFirst ? radius : Radius.zero,
          bottomLeft: isLast ? radius : Radius.zero,
          bottomRight: isLast ? radius : Radius.zero,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFirst)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (label != null && label!.isNotEmpty)
                          ? label!
                          : l10n.groupDefaultLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          child,
          if (isLast && groupCosts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 8, 10),
              child: _CostsSection(
                costs: groupCosts,
                localeName: localeName,
                onTapCost: onTapCost,
              ),
            ),
        ],
      ),
    );
  }
}

/// Left gutter with a continuous rail line and a node marker.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      width: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(child: Container(width: 2, color: line)),
          ),
          child,
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.item,
    required this.accent,
    required this.onTap,
    required this.dragHandle,
    required this.costsSection,
  });

  final ItineraryItem item;
  final Color accent;
  final VoidCallback onTap;
  final Widget? dragHandle;
  final Widget costsSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = formatTimeRange(item.startMinutes, item.endMinutes);
    final title = (item.title != null && item.title!.isNotEmpty)
        ? item.title!
        : (item.location ?? 'Place');
    final hasSubLocation =
        item.title != null &&
        item.title!.isNotEmpty &&
        item.location != null &&
        item.location!.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Gutter(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (time.isNotEmpty)
                                Text(
                                  time,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              Text(
                                title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (hasSubLocation)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.place_outlined,
                                        size: 14,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.location!,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    item.notes!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              costsSection,
                            ],
                          ),
                        ),
                        ?dragHandle,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.item,
    required this.onTap,
    required this.dragHandle,
    required this.costsSection,
  });

  final ItineraryItem item;
  final VoidCallback onTap;
  final Widget? dragHandle;
  final Widget costsSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final mode = item.mode ?? TransportMode.other;
    final time = formatTimeRange(item.startMinutes, item.endMinutes);
    final from = item.fromLocation ?? '';
    final to = item.toLocation ?? '';
    final route = [from, to].where((s) => s.isNotEmpty).join('  →  ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Gutter(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                mode.icon,
                size: 17,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      // IntrinsicHeight (needed for the rail) hands this branch a
                      // height equal to the *intrinsic* text height; on web the
                      // laid-out text is ~1px taller, which would overflow the
                      // row. OverflowBox lets that sub-pixel overrun paint into
                      // the padding instead of asserting.
                      child: OverflowBox(
                        maxHeight: double.infinity,
                        alignment: Alignment.topLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  mode.label(l10n),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (time.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    time,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (route.isNotEmpty)
                              Text(
                                route,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.notes!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            costsSection,
                          ],
                        ),
                      ),
                    ),
                    ?dragHandle,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cost chips under an itinerary item plus a per-currency subtotal when there
/// is more than one. Renders nothing when the item has no costs; costs are
/// added from the item's detail sheet.
class _CostsSection extends StatelessWidget {
  const _CostsSection({
    required this.costs,
    required this.localeName,
    required this.onTapCost,
  });

  final List<Cost> costs;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  @override
  Widget build(BuildContext context) {
    if (costs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final cost in costs)
                CostChip(cost: cost, onTap: () => onTapCost(cost)),
            ],
          ),
          if (costs.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text(
                '${l10n.costsTotal}: '
                '${formatTotals(sumByCurrency(costs), localeName)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
