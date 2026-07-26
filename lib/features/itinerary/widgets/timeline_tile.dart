import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/application/currency_providers.dart';
import '../../costs/presentation/cost_chip.dart';
import '../../transport_search/application/transport_search_controller.dart';
import '../application/transport_mode_providers.dart';
import 'item_times.dart';
import 'now_line.dart';
import 'transport_mode.dart';

/// Whether [item] opens a group's contiguous run — i.e. the row before it (its
/// [previous] neighbour in the list being rendered, or null at the top) is not in
/// the same group. The run's label is drawn on its first member.
///
/// A group lies entirely inside one alternative branch or entirely outside one,
/// so this reads the same whether the list is a day or a single branch.
bool startsGroupRun(ItineraryItem item, ItineraryItem? previous) =>
    item.groupId != null && previous?.groupId != item.groupId;

/// Whether [item] closes a group's run — the shared costs are drawn on its last
/// member. See [startsGroupRun].
bool endsGroupRun(ItineraryItem item, ItineraryItem? next) =>
    item.groupId != null && next?.groupId != item.groupId;

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
    this.isNow = false,
    this.nowLineMinutes,
    this.held = false,
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

  /// Whether this entry is under way right now.
  final bool isNow;

  /// When set, the current time (minutes since midnight): the now-line is drawn
  /// above this tile, which is the first entry of today still ahead of us.
  ///
  /// Drawn *inside* the tile rather than as a list entry of its own: the day is a
  /// `ReorderableListView` whose indices are its blocks, and an extra child would
  /// shift every one of them.
  final int? nowLineMinutes;

  /// Whether this entry is the one currently picked up, waiting to be put down
  /// somewhere else. It is dimmed rather than removed: a move that has not
  /// landed yet has changed nothing, and an entry that vanished from the day the
  /// moment you picked it up would read as deleted.
  final bool held;

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
            isNow: isNow,
          )
        : _PlaceRow(
            item: item,
            accent: accent,
            onTap: onTap,
            dragHandle: dragHandle,
            costsSection: costsSection,
            isNow: isNow,
          );

    final banded = group == null
        ? row
        : _GroupBand(
            accent: accent,
            isFirst: isFirstInGroup,
            isLast: isLastInGroup,
            label: group!.label,
            groupCosts: groupCosts,
            localeName: localeName,
            onTapCost: onTapCost,
            child: row,
          );

    final content = held ? Opacity(opacity: 0.4, child: banded) : banded;

    final nowLine = nowLineMinutes;
    if (nowLine == null) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NowLine(minutes: nowLine),
        content,
      ],
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
    required this.isNow,
  });

  final ItineraryItem item;
  final Color accent;
  final VoidCallback onTap;
  final Widget? dragHandle;
  final Widget costsSection;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = nowColor(theme);
    final hasTimes = ItemTimes.hasAny(item);
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
                // The ring both punches the rail out from behind the node and,
                // on the entry under way, marks it.
                border: Border.all(
                  color: isNow ? now : theme.colorScheme.surface,
                  width: isNow ? 3 : 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Card(
                color: isNow
                    ? Color.alphaBlend(
                        now.withValues(alpha: 0.10),
                        theme.colorScheme.surfaceContainerHighest,
                      )
                    : theme.colorScheme.surfaceContainerHighest,
                shape: isNow
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: now, width: 1.5),
                      )
                    : null,
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
                              if (hasTimes || isNow)
                                Row(
                                  children: [
                                    if (hasTimes)
                                      Flexible(
                                        child: ItemTimes(
                                          item: item,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    if (isNow) ...[
                                      const SizedBox(width: 8),
                                      const NowBadge(),
                                    ],
                                  ],
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

class _TransportRow extends ConsumerWidget {
  const _TransportRow({
    required this.item,
    required this.onTap,
    required this.dragHandle,
    required this.costsSection,
    required this.isNow,
  });

  final ItineraryItem item;
  final VoidCallback onTap;
  final Widget? dragHandle;
  final Widget costsSection;
  final bool isNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final now = nowColor(theme);
    final modeRow = ref.watch(transportModesByIdProvider)[item.mode];
    final modeIcon = modeRow?.icon ?? kDefaultTransportModeIcon;
    final modeLabel = modeRow?.label(l10n) ?? l10n.modeOther;
    final hasTimes = ItemTimes.hasAny(item);
    // The line/train number (e.g. "ICE 509"), stored as the item title, shown
    // next to the mode label. Direction and platform ride along in the notes.
    final line = item.title;
    final header = (line != null && line.isNotEmpty)
        ? '$modeLabel · $line'
        : modeLabel;
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
                border: isNow ? Border.all(color: now, width: 2) : null,
              ),
              child: Icon(
                modeIcon,
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
                                  header,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (hasTimes) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: ItemTimes(
                                      item: item,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                                if (isNow) ...[
                                  const SizedBox(width: 8),
                                  const NowBadge(),
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
                    // An imported leg (one with a routing trip id) can pull its
                    // live times; a walk transfer or hand-entered leg cannot.
                    if (item.sourceTripId != null)
                      _LiveRefreshButton(item: item),
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

/// Pulls one imported leg's live (real-time) times on demand. On success the
/// refreshed actuals write to the DB and the tile redraws with the planned-vs-
/// actual marks; a leg with no live data (already run, or schedule changed) or a
/// network failure just reports via a snackbar. Manual only — one tap, one leg.
class _LiveRefreshButton extends ConsumerStatefulWidget {
  const _LiveRefreshButton({required this.item});

  final ItineraryItem item;

  @override
  ConsumerState<_LiveRefreshButton> createState() => _LiveRefreshButtonState();
}

class _LiveRefreshButtonState extends ConsumerState<_LiveRefreshButton> {
  bool _loading = false;

  Future<void> _refresh() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final updated = await ref
          .read(transportSearchControllerProvider)
          .refreshLeg(widget.item);
      // On success the tile updates in place; only speak up when there was
      // nothing live to apply, or the fetch failed.
      if (!updated) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.liveTimesNone)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.liveTimesError)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).liveTimesRefresh,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      onPressed: _loading ? null : _refresh,
    );
  }
}

/// Cost chips under an itinerary item plus a per-currency subtotal when there
/// is more than one. Renders nothing when the item has no costs; costs are
/// added from the item's detail sheet.
class _CostsSection extends ConsumerWidget {
  const _CostsSection({
    required this.costs,
    required this.localeName,
    required this.onTapCost,
  });

  final List<Cost> costs;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (costs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(currencyBookProvider);
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
                '${formatTotals(sumByCurrency(costs, book), book, localeName)}',
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
