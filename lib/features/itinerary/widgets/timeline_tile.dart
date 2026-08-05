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
import '../now_marker.dart';
import 'item_times.dart';
import 'live_refresh_button.dart';
import 'now_line.dart';
import 'transport_mode.dart';

/// A single row in the itinerary timeline. Renders as a place stop or, for
/// transport items, as a lighter connector between stops.
///
/// A row is one *entry*. The run an entry belongs to is drawn by
/// [GroupRunTile], which owns the band and hands each member its row — so
/// nothing here has to work out where a group begins or ends.
class TimelineTile extends StatelessWidget {
  const TimelineTile({
    super.key,
    required this.item,
    required this.accent,
    required this.onTap,
    required this.costs,
    required this.localeName,
    required this.onTapCost,
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

  /// Opens this entry's journey, for an imported leg standing on its own. Null
  /// when there is no journey to read — and always null for a leg inside a run,
  /// whose journey is the run's and opens from the band above it.
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
            onShowJourney: onShowJourney,
          )
        : _PlaceRow(
            item: item,
            accent: accent,
            onTap: onTap,
            dragHandle: dragHandle,
            costsSection: costsSection,
            isNow: isNow,
          );

    final content = held ? Opacity(opacity: 0.4, child: row) : row;

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

/// A whole group — a run of entries sharing one ticket — drawn as one unit: a
/// tinted band with the group's label above its members and the shared expense
/// below them.
///
/// The run is **one block** of the list it sits in (`GroupBlock`), so it drags
/// as one and no drag can pull a leg out of the middle of it. Its members are a
/// reorderable list of their own inside the band, which is the same arrangement
/// a decision has: a card that moves as a unit in the day, holding a list that
/// reorders within itself. Before this, each member was its own slot in the day
/// — a run could be dragged apart, and the two halves went on claiming to be one
/// group, printing the shared ticket under each of them.
class GroupRunTile extends StatelessWidget {
  const GroupRunTile({
    super.key,
    required this.groupId,
    required this.label,
    required this.items,
    required this.accent,
    required this.costsByItem,
    required this.groupCosts,
    required this.localeName,
    required this.onTapItem,
    required this.onTapCost,
    required this.onReorder,
    required this.held,
    this.onShowJourney,
    this.dragHandle,
    this.isNow = false,
    this.nowMinutes,
    this.nowLineMinutes,
  });

  final int groupId;

  /// The group's name, or null/empty for the default label.
  final String? label;

  /// The run's members, in order. Never empty.
  final List<ItineraryItem> items;
  final Color accent;
  final Map<int, List<Cost>> costsByItem;

  /// The run's shared expenses, drawn once under it.
  final List<Cost> groupCosts;
  final String localeName;
  final ValueChanged<ItineraryItem> onTapItem;
  final ValueChanged<Cost> onTapCost;

  /// Reorders the run's own members, by their index within it.
  final void Function(List<ItineraryItem> runItems, int oldIndex, int newIndex)
  onReorder;

  /// What is currently picked up, so a held member (or this whole run) is drawn
  /// dimmed where it still sits.
  final Held? held;

  /// Opens the run's journey, when it has one. It belongs on the label, which is
  /// what names the run.
  final VoidCallback? onShowJourney;

  /// The run's handle in the list *it* is a block of.
  final Widget? dragHandle;

  /// Whether the run as a whole is under way right now.
  final bool isNow;

  /// The current minute, on today only. The run marks which of its members is
  /// under way, and — exactly as a decision does inside its card — draws the
  /// now-line *between* two of them only while the run itself is under way: the
  /// boundary is inside the band, so the line is too, and the list outside sees
  /// one block that is happening.
  final int? nowMinutes;

  /// The now-line drawn above the whole run, when the line falls on its slot.
  final int? nowLineMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final now = nowMinutes;
    final marker = now == null ? null : nowMarkerForItems(items, now);
    final happeningIndex = (marker != null && marker.happening)
        ? marker.index
        : -1;
    final lineIndex = (isNow && marker != null && !marker.happening)
        ? marker.index
        : -1;

    final band = Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isNow ? 0.10 : 0.06),
        border: Border(
          left: BorderSide(color: isNow ? nowColor(theme) : accent, width: 3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                if (isNow) ...[const NowBadge(), const SizedBox(width: 4)],
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
                _GroupMenu(
                  groupId: groupId,
                  tripId: items.first.tripId,
                  accent: accent,
                ),
                ?dragHandle,
              ],
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) =>
                onReorder(items, oldIndex, newIndex),
            itemBuilder: (context, i) {
              final item = items[i];
              return TimelineTile(
                key: ValueKey('item-${item.id}'),
                item: item,
                accent: accent,
                onTap: () => onTapItem(item),
                costs: costsByItem[item.id] ?? const [],
                localeName: localeName,
                onTapCost: onTapCost,
                isNow: i == happeningIndex,
                nowLineMinutes: i == lineIndex ? now : null,
                held: isHeldItem(held, item),
                dragHandle: ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
          // Everything in the run is behind us: the line closes it off rather
          // than being dropped, the same way an option's does.
          if (lineIndex == items.length) NowLine(minutes: now!),
          if (groupCosts.isNotEmpty)
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

    final line = nowLineMinutes;
    if (line == null) return band;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NowLine(minutes: line),
        band,
      ],
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
  const _GroupMenu({
    required this.groupId,
    required this.tripId,
    required this.accent,
  });

  final int groupId;

  /// Read off a member rather than the group row: the run is on screen, so its
  /// trip is not in doubt even if the groups stream has yet to arrive.
  final int tripId;
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
                    tripId: tripId,
                    groupId: groupId,
                    mode: action == _GroupAction.move
                        ? HoldMode.move
                        : HoldMode.copy,
                  ),
                );
          case _GroupAction.delete:
            if (await _confirmDelete(context, l10n)) {
              await repo.deleteGroup(groupId);
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
