import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../day_blocks.dart';
import 'alternative_card.dart';
import 'timeline_tile.dart';

/// Renders a trip's itinerary as day sections. A day is a reorderable list of
/// **blocks**: single place/transport tiles, and decisions — a set of competing
/// options swiped through in an [AlternativeCard] — each taking one slot.
/// Non-scrolling on its own; intended to sit inside the detail screen's scroll
/// view.
class ItineraryTimeline extends StatelessWidget {
  const ItineraryTimeline({
    super.key,
    required this.items,
    required this.accent,
    required this.tripStart,
    required this.tripEnd,
    required this.onTapItem,
    required this.onAddPlace,
    required this.onQuickAddPlace,
    required this.onAddTransport,
    required this.onReorder,
    required this.onReorderBranch,
    required this.costsByItem,
    required this.groups,
    required this.costsByGroup,
    required this.sets,
    required this.branches,
    required this.localeName,
    required this.onTapCost,
    required this.collapsedDays,
    required this.onToggleDayCollapsed,
  });

  /// The trip's whole itinerary, including the items of options that were not
  /// chosen — an [AlternativeCard] draws whichever option is being looked at.
  final List<ItineraryItem> items;
  final Color accent;
  final DateTime? tripStart;
  final DateTime? tripEnd;

  /// The trip's decisions, keyed by id, and their options, keyed by decision id.
  final Map<int, AlternativeSet> sets;
  final Map<int, List<Alternative>> branches;

  /// The trip's item groups, keyed by id, to resolve a grouped item's label.
  final Map<int, ItemGroup> groups;

  /// Costs attached to a group, keyed by group id. Shown once under the group's
  /// last member and counted once toward the day total.
  final Map<int, List<Cost>> costsByGroup;

  /// The days (normalized to midnight) currently shown collapsed.
  final Set<DateTime> collapsedDays;

  /// Called when a day header is tapped, with the new collapsed state.
  final void Function(DateTime day, bool collapsed) onToggleDayCollapsed;
  final ValueChanged<ItineraryItem> onTapItem;

  /// Opens the add-place form for [day], or for one option of a decision on that
  /// day when [alternativeId] is given.
  final void Function(DateTime day, {int? alternativeId}) onAddPlace;

  /// Creates a place for [day] — or inside one option of a decision on it —
  /// pre-named with the given location, with no form step. Used by the "you just
  /// arrived here" quick-add chip.
  final void Function(DateTime day, String location, {int? alternativeId})
  onQuickAddPlace;

  /// Opens the add-transport form for [day] (or for one option of a decision on
  /// it). [fromDefault] is the current location — where the previous entry
  /// leaves you — pre-filled into the "from" field, or null if there is none.
  final void Function(
    DateTime day,
    String? fromDefault, {
    int? alternativeId,
  }) onAddTransport;
  final Map<int, List<Cost>> costsByItem;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  /// Called when a block is dragged within a day. [dayBlocks] is that day's list
  /// in its current order; [newIndex] is the block's final position (already
  /// adjusted for the removal at [oldIndex], per ReorderableListView.onReorderItem).
  final void Function(List<DayBlock> dayBlocks, int oldIndex, int newIndex)
  onReorder;

  /// Called when a tile is dragged within one option of a decision.
  final void Function(
    List<ItineraryItem> branchItems,
    int oldIndex,
    int newIndex,
  ) onReorderBranch;

  List<DateTime> _daysToShow() {
    final days = SplayTreeSet<DateTime>();
    if (tripStart != null && tripEnd != null) {
      var d = normalizeDay(tripStart!);
      final end = normalizeDay(tripEnd!);
      while (!d.isAfter(end)) {
        days.add(d);
        d = d.add(const Duration(days: 1));
      }
    }
    // An item inside an option belongs to the day of its decision, not to its
    // own date, so it can never pull a day into existence on its own.
    for (final item in items) {
      if (item.alternativeId == null) days.add(normalizeDay(item.date));
    }
    for (final set in sets.values) {
      days.add(normalizeDay(set.date));
    }
    return days.toList();
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysToShow();

    if (days.isEmpty) {
      // No trip dates and no items yet: offer a single "today" section.
      final today = normalizeDay(DateTime.now());
      return _DaySection(
        day: today,
        dayNumber: 1,
        blocks: const [],
        accent: accent,
        collapsed: collapsedDays.contains(today),
        onToggleCollapsed: onToggleDayCollapsed,
        onTapItem: onTapItem,
        onAddPlace: onAddPlace,
        onQuickAddPlace: onQuickAddPlace,
        onAddTransport: onAddTransport,
        onReorder: onReorder,
        onReorderBranch: onReorderBranch,
        costsByItem: costsByItem,
        groups: groups,
        costsByGroup: costsByGroup,
        localeName: localeName,
        onTapCost: onTapCost,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < days.length; i++)
          _DaySection(
            key: ValueKey(days[i]),
            day: days[i],
            dayNumber: i + 1,
            blocks: buildDayBlocks(
              day: days[i],
              items: items,
              sets: sets,
              branchesBySet: branches,
            ),
            accent: accent,
            collapsed: collapsedDays.contains(days[i]),
            onToggleCollapsed: onToggleDayCollapsed,
            onTapItem: onTapItem,
            onAddPlace: onAddPlace,
            onQuickAddPlace: onQuickAddPlace,
            onAddTransport: onAddTransport,
            onReorder: onReorder,
            onReorderBranch: onReorderBranch,
            costsByItem: costsByItem,
            groups: groups,
            costsByGroup: costsByGroup,
            localeName: localeName,
            onTapCost: onTapCost,
          ),
      ],
    );
  }
}


/// One day of the trip: a header that collapses the day, its blocks (tiles and
/// decisions) as one reorderable list, and the day's add actions.
class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.day,
    required this.dayNumber,
    required this.blocks,
    required this.accent,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onTapItem,
    required this.onAddPlace,
    required this.onQuickAddPlace,
    required this.onAddTransport,
    required this.onReorder,
    required this.onReorderBranch,
    required this.costsByItem,
    required this.groups,
    required this.costsByGroup,
    required this.localeName,
    required this.onTapCost,
  });

  final DateTime day;
  final int dayNumber;

  /// The day's blocks in order: single items and whole decisions.
  final List<DayBlock> blocks;
  final Color accent;
  final Map<int, ItemGroup> groups;
  final Map<int, List<Cost>> costsByGroup;

  /// Whether this day is shown collapsed.
  final bool collapsed;

  /// Called when the header is tapped, with the new collapsed state.
  final void Function(DateTime day, bool collapsed) onToggleCollapsed;
  final ValueChanged<ItineraryItem> onTapItem;
  final void Function(DateTime day, {int? alternativeId}) onAddPlace;
  final void Function(DateTime day, String location, {int? alternativeId})
  onQuickAddPlace;
  final void Function(DateTime day, String? fromDefault, {int? alternativeId})
  onAddTransport;
  final void Function(List<DayBlock>, int, int) onReorder;
  final void Function(List<ItineraryItem>, int, int) onReorderBranch;
  final Map<int, List<Cost>> costsByItem;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  /// The day's plan as it stands: its loose items plus the items of the chosen
  /// option of each decision. What the day *totals* and what the "you are here"
  /// chips read from — an option not taken is not part of the day.
  List<ItineraryItem> get _liveItems => [
    for (final block in blocks)
      ...switch (block) {
        ItemBlock(:final item) => [item],
        DecisionBlock(:final chosen, :final itemsByBranch) =>
          itemsByBranch[chosen.id] ?? const [],
      },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final expanded = !collapsed;
    final live = _liveItems;
    final count = live.length;
    // The day's expenses: each live item's own costs, plus each group's shared
    // cost counted once (a group may have several members on the day, but one
    // expense). The costs of options not chosen are shown on their option's card
    // but never in this total.
    final groupIdsToday = {
      for (final item in live)
        if (item.groupId != null) item.groupId!,
    };
    final dayCosts = [
      for (final item in live) ...?costsByItem[item.id],
      for (final groupId in groupIdsToday) ...?costsByGroup[groupId],
    ];
    final dayTotals = sumByCurrency(dayCosts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable header that collapses/expands the whole day.
        InkWell(
          onTap: () => onToggleCollapsed(day, expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: accent,
                  child: Text(
                    '$dayNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDay(day, localeName),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (dayTotals.isNotEmpty)
                        Text(
                          '${l10n.costsTotal}: '
                          '${formatTotals(dayTotals, localeName)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!expanded && count > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      l10n.entries(count),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: expanded
                      ? l10n.hideEntries
                      : l10n.showEntries,
                ),
              ],
            ),
          ),
        ),
        // Collapsible body: the entries and the add actions.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? _buildBody(context, theme)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final live = _liveItems;
    final lastItem = live.isEmpty ? null : live.last;
    // The day's current location: where the last entry leaves you — a place's
    // location, or a leg's destination. Used to pre-fill the next leg's "from"
    // and, when it comes from a leg, to offer the arrival quick-add chip.
    final currentLocation = switch (lastItem?.kind) {
      ItemKind.place => lastItem!.location?.trim(),
      ItemKind.transport => lastItem!.toLocation?.trim(),
      null => null,
    };
    final hasCurrentLocation =
        currentLocation != null && currentLocation.isNotEmpty;
    // If the day ends on a transport leg with a destination, offer a one-tap
    // chip to add that arrival as a place — no typing the same name again.
    final arrival = hasCurrentLocation && lastItem!.kind == ItemKind.transport
        ? currentLocation
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 4, 4, 4),
            child: Text(
              l10n.nothingPlanned,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: blocks.length,
            onReorderItem: (oldIndex, newIndex) =>
                onReorder(blocks, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final block = blocks[index];
              final dragHandle = ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.drag_indicator,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
              return switch (block) {
                ItemBlock(:final item) => _itemTile(
                  index: index,
                  item: item,
                  dragHandle: dragHandle,
                ),
                DecisionBlock() => AlternativeCard(
                  key: ValueKey('set-${block.set.id}'),
                  block: block,
                  accent: accent,
                  groups: groups,
                  costsByItem: costsByItem,
                  costsByGroup: costsByGroup,
                  localeName: localeName,
                  onTapItem: onTapItem,
                  onTapCost: onTapCost,
                  onAddPlace: (branchId) =>
                      onAddPlace(day, alternativeId: branchId),
                  onAddTransport: (branchId) => onAddTransport(
                    day,
                    _branchLastLocation(block, branchId),
                    alternativeId: branchId,
                  ),
                  onQuickAddPlace: (branchId, location) => onQuickAddPlace(
                    day,
                    location,
                    alternativeId: branchId,
                  ),
                  onReorderBranch: onReorderBranch,
                  dragHandle: dragHandle,
                ),
              };
            },
          ),
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 4),
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => onAddPlace(day),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: Text(l10n.addPlace),
              ),
              if (arrival != null)
                ActionChip(
                  avatar: const Icon(Icons.place, size: 16),
                  label: Text(l10n.addArrival(arrival)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onQuickAddPlace(day, arrival),
                ),
              TextButton.icon(
                onPressed: () => onAddTransport(
                  day,
                  hasCurrentLocation ? currentLocation : null,
                ),
                icon: const Icon(Icons.alt_route, size: 18),
                label: Text(l10n.addTransport),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A loose item's tile. Its group run is read against its neighbouring blocks:
  /// a group never spans a decision, so a decision in between simply ends the run.
  Widget _itemTile({
    required int index,
    required ItineraryItem item,
    required Widget dragHandle,
  }) {
    ItineraryItem? neighbour(int at) {
      if (at < 0 || at >= blocks.length) return null;
      final block = blocks[at];
      return block is ItemBlock ? block.item : null;
    }

    final groupId = item.groupId;
    return TimelineTile(
      key: ValueKey('item-${item.id}'),
      item: item,
      accent: accent,
      onTap: () => onTapItem(item),
      costs: costsByItem[item.id] ?? const [],
      group: groupId == null ? null : groups[groupId],
      isFirstInGroup: startsGroupRun(item, neighbour(index - 1)),
      isLastInGroup: endsGroupRun(item, neighbour(index + 1)),
      groupCosts: groupId == null ? const [] : (costsByGroup[groupId] ?? const []),
      localeName: localeName,
      onTapCost: onTapCost,
      dragHandle: dragHandle,
    );
  }

  /// Where an option's last entry leaves you, to pre-fill the "from" field of a
  /// leg added to that option.
  String? _branchLastLocation(DecisionBlock block, int branchId) {
    final items = block.itemsByBranch[branchId] ?? const [];
    if (items.isEmpty) return null;
    final last = items.last;
    final location = switch (last.kind) {
      ItemKind.place => last.location?.trim(),
      ItemKind.transport => last.toLocation?.trim(),
    };
    return (location == null || location.isEmpty) ? null : location;
  }
}
