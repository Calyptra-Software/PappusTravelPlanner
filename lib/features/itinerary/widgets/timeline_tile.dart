import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/application/currency_providers.dart';
import '../../costs/presentation/cost_chip.dart';
import '../application/item_clipboard.dart';
import '../application/transport_mode_providers.dart';
import 'item_times.dart';
import 'live_refresh_button.dart';
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
    this.onShowJourney,
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

  /// Opens this entry's journey — the whole group's when it is in one, the leg's
  /// own when it stands alone. Null when there is no journey to read: the caller
  /// decides that, since it is the one holding the group's other members.
  ///
  /// It is drawn where the unit it opens lives: on the group's header, which
  /// names the run, or on the leg's own row. Never on both — a grouped leg's
  /// journey is its group's.
  final VoidCallback? onShowJourney;
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
            onShowJourney: group == null ? onShowJourney : null,
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
            group: group!,
            groupCosts: groupCosts,
            onShowJourney: onShowJourney,
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
    required this.group,
    required this.groupCosts,
    required this.onShowJourney,
    required this.localeName,
    required this.onTapCost,
    required this.child,
  });

  final Color accent;
  final bool isFirst;
  final bool isLast;
  final ItemGroup group;
  final List<Cost> groupCosts;
  final VoidCallback? onShowJourney;
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
                      (group.label != null && group.label!.isNotEmpty)
                          ? group.label!
                          : l10n.groupDefaultLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // A group of legs is a journey — the run added by one import,
                  // sharing one ticket — so the way to read it back sits on the
                  // label that says as much.
                  if (onShowJourney case final show?)
                    IconButton(
                      tooltip: l10n.journeyDetails,
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      icon: const Icon(Icons.route),
                      color: accent,
                      onPressed: show,
                    ),
                  // What is done to the run as a whole belongs on the run's own
                  // label, not inside one member's edit form: a shared-ticket
                  // journey is moved and deleted as one thing, and the label is
                  // the only place that names that thing.
                  _GroupMenu(group: group, accent: accent),
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

/// What can be done to a whole group, on the group's own label.
///
/// Moving and copying were reachable before, but only from the *grouping*
/// section of one member's edit form — a place you go to change that entry,
/// and which says nothing about the run standing above it. Deleting a run had
/// no path at all: an entry deleted one at a time takes the group with it only
/// once it is down to its last member, and the shared ticket is rescued onto
/// whichever leg happened to be left, so a journey removed leg by leg left its
/// fare behind, attached to nothing anyone had meant to keep.
///
/// The three acts share one shape with the rest of the app: move and copy pick
/// the run up into [itemClipboardProvider] and let the destination name itself
/// (the run stays where it is, dimmed, until it is put down), while the
/// destructive one asks first.
class _GroupMenu extends ConsumerWidget {
  const _GroupMenu({required this.group, required this.accent});

  final ItemGroup group;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_GroupAction>(
      tooltip: l10n.groupActions,
      icon: const Icon(Icons.more_vert, size: 20),
      iconColor: accent,
      onSelected: (action) async {
        final repo = ref.read(repositoryProvider);
        switch (action) {
          case _GroupAction.move:
          case _GroupAction.copy:
            ref
                .read(itemClipboardProvider.notifier)
                .hold(
                  HeldGroup(
                    tripId: group.tripId,
                    groupId: group.id,
                    mode: action == _GroupAction.move
                        ? HoldMode.move
                        : HoldMode.copy,
                  ),
                );
          case _GroupAction.delete:
            if (await _confirmDelete(context, l10n)) {
              await repo.deleteGroup(group.id);
            }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: _GroupAction.move, child: Text(l10n.groupMoveTo)),
        PopupMenuItem(value: _GroupAction.copy, child: Text(l10n.groupCopyTo)),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _GroupAction.delete,
          child: Text(l10n.groupDelete),
        ),
      ],
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.groupDeleteQuestion),
        content: Text(l10n.groupDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

enum _GroupAction { move, copy, delete }

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
    required this.onShowJourney,
  });

  final ItineraryItem item;
  final VoidCallback onTap;
  final Widget? dragHandle;
  final Widget costsSection;
  final bool isNow;
  final VoidCallback? onShowJourney;

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
                    // An imported leg standing outside a group carries its own
                    // way into the journey sheet; inside a group the run's
                    // header has it.
                    if (onShowJourney case final show?)
                      IconButton(
                        tooltip: l10n.journeyDetails,
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        icon: const Icon(Icons.route),
                        onPressed: show,
                      ),
                    // An imported leg (one with a routing trip id) can pull its
                    // live times; a walk transfer or hand-entered leg cannot.
                    if (item.sourceTripId != null)
                      LiveRefreshButton(item: item),
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
