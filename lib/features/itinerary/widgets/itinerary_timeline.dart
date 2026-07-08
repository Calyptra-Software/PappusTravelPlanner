import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import 'timeline_tile.dart';

/// Renders a trip's itinerary as day sections, each a reorderable list of
/// place/transport tiles with per-day add actions. Non-scrolling on its own —
/// intended to sit inside the detail screen's scroll view.
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
    required this.costsByItem,
    required this.groups,
    required this.costsByGroup,
    required this.localeName,
    required this.onTapCost,
    required this.collapsedDays,
    required this.onToggleDayCollapsed,
  });

  final List<ItineraryItem> items;
  final Color accent;
  final DateTime? tripStart;
  final DateTime? tripEnd;

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
  final ValueChanged<DateTime> onAddPlace;

  /// Creates a place for [day] pre-named with the given location, with no form
  /// step. Used by the "you just arrived here" quick-add chip.
  final void Function(DateTime day, String location) onQuickAddPlace;

  /// Opens the add-transport form for [day]. [fromDefault] is the day's current
  /// location (where the previous entry left you), pre-filled into the "from"
  /// field, or null if the day has no usable location yet.
  final void Function(DateTime day, String? fromDefault) onAddTransport;
  final Map<int, List<Cost>> costsByItem;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  /// Called when a tile is dragged within a day. [dayItems] is that day's list
  /// in its current order; [newIndex] is the item's final position (already
  /// adjusted for the removal at [oldIndex], per ReorderableListView.onReorderItem).
  final void Function(List<ItineraryItem> dayItems, int oldIndex, int newIndex)
  onReorder;

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
    for (final item in items) {
      days.add(normalizeDay(item.date));
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
        items: const [],
        accent: accent,
        collapsed: collapsedDays.contains(today),
        onToggleCollapsed: onToggleDayCollapsed,
        onTapItem: onTapItem,
        onAddPlace: onAddPlace,
        onQuickAddPlace: onQuickAddPlace,
        onAddTransport: onAddTransport,
        onReorder: onReorder,
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
            items: items
                .where((it) => normalizeDay(it.date) == days[i])
                .toList(),
            accent: accent,
            collapsed: collapsedDays.contains(days[i]),
            onToggleCollapsed: onToggleDayCollapsed,
            onTapItem: onTapItem,
            onAddPlace: onAddPlace,
            onQuickAddPlace: onQuickAddPlace,
            onAddTransport: onAddTransport,
            onReorder: onReorder,
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

class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.day,
    required this.dayNumber,
    required this.items,
    required this.accent,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onTapItem,
    required this.onAddPlace,
    required this.onQuickAddPlace,
    required this.onAddTransport,
    required this.onReorder,
    required this.costsByItem,
    required this.groups,
    required this.costsByGroup,
    required this.localeName,
    required this.onTapCost,
  });

  final DateTime day;
  final int dayNumber;
  final List<ItineraryItem> items;
  final Color accent;
  final Map<int, ItemGroup> groups;
  final Map<int, List<Cost>> costsByGroup;

  /// Whether this day is shown collapsed.
  final bool collapsed;

  /// Called when the header is tapped, with the new collapsed state.
  final void Function(DateTime day, bool collapsed) onToggleCollapsed;
  final ValueChanged<ItineraryItem> onTapItem;
  final ValueChanged<DateTime> onAddPlace;
  final void Function(DateTime day, String location) onQuickAddPlace;
  final void Function(DateTime day, String? fromDefault) onAddTransport;
  final void Function(List<ItineraryItem>, int, int) onReorder;
  final Map<int, List<Cost>> costsByItem;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final expanded = !collapsed;
    final count = items.length;
    // Per-item costs for the day, plus each group's shared costs counted once
    // (a group may have several members on the day, but one expense).
    final groupIdsToday = {
      for (final item in items)
        if (item.groupId != null) item.groupId!,
    };
    final dayCosts = [
      for (final item in items) ...?costsByItem[item.id],
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
    final lastItem = items.isEmpty ? null : items.last;
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
    final arrival =
        hasCurrentLocation && lastItem!.kind == ItemKind.transport
        ? currentLocation
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty)
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
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) =>
                onReorder(items, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final item = items[index];
              // A group renders as a contiguous run within the day: its label
              // heads the first member and its shared costs sit under the last.
              final groupId = item.groupId;
              final inGroup = groupId != null;
              final isFirstInGroup = inGroup &&
                  (index == 0 || items[index - 1].groupId != groupId);
              final isLastInGroup = inGroup &&
                  (index == items.length - 1 ||
                      items[index + 1].groupId != groupId);
              return TimelineTile(
                key: ValueKey(item.id),
                item: item,
                accent: accent,
                onTap: () => onTapItem(item),
                costs: costsByItem[item.id] ?? const [],
                group: inGroup ? groups[groupId] : null,
                isFirstInGroup: isFirstInGroup,
                isLastInGroup: isLastInGroup,
                groupCosts: inGroup ? (costsByGroup[groupId] ?? const []) : const [],
                localeName: localeName,
                onTapCost: onTapCost,
                dragHandle: ReorderableDragStartListener(
                  index: index,
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
}
