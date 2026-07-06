import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
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
    required this.onAddTransport,
    required this.onReorder,
    required this.costsByItem,
    required this.localeName,
    required this.onTapCost,
  });

  final List<ItineraryItem> items;
  final Color accent;
  final DateTime? tripStart;
  final DateTime? tripEnd;
  final ValueChanged<ItineraryItem> onTapItem;
  final ValueChanged<DateTime> onAddPlace;
  final ValueChanged<DateTime> onAddTransport;
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
        onTapItem: onTapItem,
        onAddPlace: onAddPlace,
        onAddTransport: onAddTransport,
        onReorder: onReorder,
        costsByItem: costsByItem,
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
            onTapItem: onTapItem,
            onAddPlace: onAddPlace,
            onAddTransport: onAddTransport,
            onReorder: onReorder,
            costsByItem: costsByItem,
            localeName: localeName,
            onTapCost: onTapCost,
          ),
      ],
    );
  }
}

class _DaySection extends StatefulWidget {
  const _DaySection({
    super.key,
    required this.day,
    required this.dayNumber,
    required this.items,
    required this.accent,
    required this.onTapItem,
    required this.onAddPlace,
    required this.onAddTransport,
    required this.onReorder,
    required this.costsByItem,
    required this.localeName,
    required this.onTapCost,
  });

  final DateTime day;
  final int dayNumber;
  final List<ItineraryItem> items;
  final Color accent;
  final ValueChanged<ItineraryItem> onTapItem;
  final ValueChanged<DateTime> onAddPlace;
  final ValueChanged<DateTime> onAddTransport;
  final void Function(List<ItineraryItem>, int, int) onReorder;
  final Map<int, List<Cost>> costsByItem;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  @override
  State<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<_DaySection> {
  bool _expanded = true;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final count = widget.items.length;
    final dayCosts = [
      for (final item in widget.items) ...?widget.costsByItem[item.id],
    ];
    final dayTotals = sumByCurrency(dayCosts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable header that collapses/expands the whole day.
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: widget.accent,
                  child: Text(
                    '${widget.dayNumber}',
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
                        formatDay(widget.day, localeName),
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
                if (!_expanded && count > 0)
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
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: _expanded
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
          child: _expanded
              ? _buildBody(context, theme)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isEmpty)
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
            itemCount: widget.items.length,
            onReorderItem: (oldIndex, newIndex) =>
                widget.onReorder(widget.items, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return TimelineTile(
                key: ValueKey(item.id),
                item: item,
                accent: widget.accent,
                onTap: () => widget.onTapItem(item),
                costs: widget.costsByItem[item.id] ?? const [],
                localeName: widget.localeName,
                onTapCost: widget.onTapCost,
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
                onPressed: () => widget.onAddPlace(widget.day),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: Text(l10n.addPlace),
              ),
              TextButton.icon(
                onPressed: () => widget.onAddTransport(widget.day),
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
