import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/application/currency_providers.dart';
import '../../transport_search/presentation/journey_details_sheet.dart';
import '../application/item_clipboard.dart';
import '../day_blocks.dart';
import '../now_marker.dart';
import 'alternative_card.dart';
import 'now_line.dart';
import 'put_down_chip.dart';
import 'timeline_tile.dart';

/// Renders a trip's itinerary as day sections. A day is a reorderable list of
/// **blocks**: single place/transport tiles, and decisions — a set of competing
/// options swiped through in an [AlternativeCard] — each taking one slot.
/// Non-scrolling on its own; intended to sit inside the detail screen's scroll
/// view.
class ItineraryTimeline extends StatefulWidget {
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
    required this.onReorderRun,
    required this.costsByItem,
    required this.groups,
    required this.costsByGroup,
    required this.sets,
    required this.branches,
    required this.localeName,
    required this.onTapCost,
    required this.collapsedDays,
    required this.onToggleDayCollapsed,
    required this.now,
    required this.held,
    required this.onPutDown,
    this.todayKey,
    this.anchorDay,
    this.relativeDays = false,
    this.canAddDay = false,
  });

  /// Where an entry added to an *empty* plan lands, when the trip's own dates
  /// do not say. A routine must anchor on its day one rather than on today, or
  /// its plan would scatter across whichever days it happened to be written on.
  final DateTime? anchorDay;

  /// Whether the plan can grow a day on demand — true for a routine, whose days
  /// are ordinals it appends to rather than dates on a calendar.
  final bool canAddDay;

  /// Whether the days are numbered rather than dated — a routine has no dates,
  /// so its days read "Day 1", "Day 2". Everything else about a day is
  /// unchanged: it is the same list, ordered and grouped the same way, and the
  /// numbers were already being computed for the header's badge.
  final bool relativeDays;

  /// The entry currently picked up, or null. While one is held, every day and
  /// every option offers to put it down; the entry itself is drawn dimmed where
  /// it still sits.
  final Held? held;

  /// Puts the held entry at the end of [day], or of [alternativeId]'s option.
  final void Function(DateTime day, {int? alternativeId}) onPutDown;

  /// The trip's whole itinerary, including the items of options that were not
  /// chosen — an [AlternativeCard] draws whichever option is being looked at.
  final List<ItineraryItem> items;
  final Color accent;
  final DateTime? tripStart;
  final DateTime? tripEnd;

  /// The current time, ticking on the minute (`nowProvider`). The day it falls on
  /// — if the trip has one — carries the "you are here" mark.
  final DateTime now;

  /// Attached to today's day section, so the screen can scroll it into view.
  final GlobalKey? todayKey;

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
  final void Function(DateTime day, String? fromDefault, {int? alternativeId})
  onAddTransport;
  final Map<int, List<Cost>> costsByItem;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  /// Called when a block is dragged within a day. [dayBlocks] is that day's list
  /// in its current order; [newIndex] is the block's final position (already
  /// adjusted for the removal at [oldIndex], per ReorderableListView.onReorderItem).
  final void Function(List<DayBlock> dayBlocks, int oldIndex, int newIndex)
  onReorder;

  /// Called when a block is dragged within one option of a decision — its
  /// entries and its runs, ordered exactly as a day's blocks are.
  final void Function(List<DayBlock> branchBlocks, int oldIndex, int newIndex)
  onReorderBranch;

  /// Called when a tile is dragged within a run — a group's own list, inside the
  /// band that draws it. The run keeps the slots it already occupies; only its
  /// members' order among themselves changes.
  final void Function(List<ItineraryItem> runItems, int oldIndex, int newIndex)
  onReorderRun;

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
  State<ItineraryTimeline> createState() => _ItineraryTimelineState();
}

class _ItineraryTimelineState extends State<ItineraryTimeline> {
  /// A day the user has asked for but not yet planned anything on.
  ///
  /// A dateless plan's days *are* its entries, so an empty day cannot be
  /// stored — there is nothing to store. It exists here, on screen, only until
  /// something is put on it; leaving the trip forgets it, which is right, since
  /// an empty day says nothing worth keeping.
  DateTime? _pendingDay;

  @override
  Widget build(BuildContext context) {
    final days = widget._daysToShow();
    final pending = _pendingDay;
    // Only while it is still empty: once something lands on it the day comes
    // from the plan like any other, and a second copy would draw it twice.
    if (pending != null && !days.contains(pending)) days.add(pending);
    days.sort();
    final today = normalizeDay(widget.now);

    if (days.isEmpty) {
      // Nothing dated and nothing in the plan yet: offer a single section. It
      // is the plan's own anchor when it has one (a routine's day one), and
      // today otherwise.
      final blank = widget.anchorDay == null
          ? today
          : normalizeDay(widget.anchorDay!);
      return _DaySection(
        day: blank,
        dayNumber: 1,
        blocks: const [],
        accent: widget.accent,
        collapsed: widget.collapsedDays.contains(today),
        onToggleCollapsed: widget.onToggleDayCollapsed,
        onTapItem: widget.onTapItem,
        onAddPlace: widget.onAddPlace,
        onQuickAddPlace: widget.onQuickAddPlace,
        onAddTransport: widget.onAddTransport,
        onReorder: widget.onReorder,
        onReorderBranch: widget.onReorderBranch,
        onReorderRun: widget.onReorderRun,
        costsByItem: widget.costsByItem,
        groups: widget.groups,
        costsByGroup: widget.costsByGroup,
        localeName: widget.localeName,
        onTapCost: widget.onTapCost,
        now: widget.now,
        held: widget.held,
        onPutDown: widget.onPutDown,
        anchorKey: widget.todayKey,
        showHeader: false,
        relativeDays: widget.relativeDays,
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
              items: widget.items,
              sets: widget.sets,
              branchesBySet: widget.branches,
            ),
            accent: widget.accent,
            collapsed: widget.collapsedDays.contains(days[i]),
            onToggleCollapsed: widget.onToggleDayCollapsed,
            onTapItem: widget.onTapItem,
            onAddPlace: widget.onAddPlace,
            onQuickAddPlace: widget.onQuickAddPlace,
            onAddTransport: widget.onAddTransport,
            onReorder: widget.onReorder,
            onReorderBranch: widget.onReorderBranch,
            onReorderRun: widget.onReorderRun,
            costsByItem: widget.costsByItem,
            groups: widget.groups,
            costsByGroup: widget.costsByGroup,
            localeName: widget.localeName,
            onTapCost: widget.onTapCost,
            now: widget.now,
            held: widget.held,
            onPutDown: widget.onPutDown,
            anchorKey: days[i] == today ? widget.todayKey : null,
            // One day needs no heading: it names nothing the trip's own header
            // does not already say, and the collapse it carries would fold the
            // whole trip away. This is derived, not declared — a trip that
            // shrinks to a single day gets the compact reading for free.
            showHeader: days.length > 1,
            relativeDays: widget.relativeDays,
          ),
        if (widget.canAddDay) _addDayButton(context, days),
      ],
    );
  }

  /// Grows the plan by a day.
  ///
  /// A dated trip needs no such thing — its days come from its dates — but a
  /// routine's days are ordinals, and without this the only way to reach day two
  /// was to know it is stored as the day after the anchor and to type that date
  /// into a calendar. Nothing is written: the day appears, and becomes real as
  /// soon as something is planned on it.
  Widget _addDayButton(BuildContext context, List<DateTime> days) {
    final l10n = AppLocalizations.of(context);
    // One empty day at a time. A second would be a row of blank days, and the
    // first one is not real yet.
    final pending = _pendingDay;
    if (pending != null &&
        !widget.items.any((i) => normalizeDay(i.date) == pending)) {
      return const SizedBox.shrink();
    }
    final next = days.isEmpty
        ? normalizeDay(widget.anchorDay ?? widget.now)
        : addDays(days.last, 1);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: TextButton.icon(
        onPressed: () => setState(() => _pendingDay = next),
        icon: const Icon(Icons.add),
        label: Text(l10n.routineAddDay),
      ),
    );
  }
}

/// One day of the trip: a header that collapses the day, its blocks (tiles and
/// decisions) as one reorderable list, and the day's add actions.
class _DaySection extends ConsumerWidget {
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
    required this.onReorderRun,
    required this.costsByItem,
    required this.groups,
    required this.costsByGroup,
    required this.localeName,
    required this.onTapCost,
    required this.now,
    required this.held,
    required this.onPutDown,
    this.anchorKey,
    this.showHeader = true,
    this.relativeDays = false,
  });

  /// Whether this day is named by its number rather than its date — see
  /// [ItineraryTimeline.relativeDays].
  final bool relativeDays;

  final Held? held;
  final void Function(DateTime day, {int? alternativeId}) onPutDown;

  /// Whether the day's own header — its number, date, total and collapse — is
  /// drawn. False on a one-day trip, where there is no second day to tell this
  /// one apart from and nothing above it worth folding away.
  final bool showHeader;

  final DateTime day;
  final int dayNumber;

  /// The current time. When it falls on [day], the day is marked as today and
  /// carries the now-line.
  final DateTime now;

  /// Attached to this section's header when it is today, so it can be scrolled
  /// into view.
  final GlobalKey? anchorKey;

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
  final void Function(List<DayBlock>, int, int) onReorderBranch;
  final void Function(List<ItineraryItem>, int, int) onReorderRun;
  final Map<int, List<Cost>> costsByItem;
  final String localeName;
  final ValueChanged<Cost> onTapCost;

  /// The day's plan as it stands: its loose items plus the items of the chosen
  /// option of each decision. What the day *totals* and what the "you are here"
  /// chips read from — an option not taken is not part of the day.
  List<ItineraryItem> get _liveItems => itemsInDayOrder(blocks);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final book = ref.watch(currencyBookProvider);
    // With no header there is nothing to collapse *with*, so a one-day trip is
    // always expanded — otherwise a stored collapsed flag could hide the whole
    // timeline behind a control that is not on screen.
    final expanded = showHeader ? !collapsed : true;
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
    final dayTotals = sumByCurrency(dayCosts, book);
    // A routine's days are numbers, not dates, so none of them is today — the
    // anchor day is an offset origin, not a date the user is living through.
    final isToday = !relativeDays && normalizeDay(now) == day;
    final nowMinutes = now.hour * 60 + now.minute;
    final today = nowColor(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable header that collapses/expands the whole day. On today it also
        // carries the clock: the day can be collapsed, and then this is the only
        // place left to say where in the trip we are.
        if (showHeader)
          InkWell(
            key: anchorKey,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                // A routine has no dates: its days are the
                                // positions in a plan, so they are numbered.
                                // Printing the anchor would show 1 January 1970.
                                relativeDays
                                    ? l10n.routineDayNumber(dayNumber)
                                    : formatDay(day, localeName),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${l10n.today} · ${formatMinutes(nowMinutes)}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: today,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (dayTotals.isNotEmpty)
                          Text(
                            '${l10n.costsTotal}: '
                            '${formatTotals(dayTotals, book, localeName)}',
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
    final nowMinutes = now.hour * 60 + now.minute;
    // Where today stands: either an entry is under way, or the day divides into
    // what is behind us and what is ahead. Null on any other day, and on a day
    // that carries no times at all — the header's clock says the rest.
    final isToday = normalizeDay(now) == day;
    final marker = isToday ? nowMarker(blocks, nowMinutes) : null;
    final happeningIndex = (marker != null && marker.happening)
        ? marker.index
        : -1;
    // The block the line is drawn above; == blocks.length when the whole day is
    // behind us, and the line goes under the last block instead.
    final lineIndex = (marker != null && !marker.happening) ? marker.index : -1;
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
                  context: context,
                  item: item,
                  dragHandle: dragHandle,
                  isNow: index == happeningIndex,
                  nowLineMinutes: index == lineIndex ? nowMinutes : null,
                ),
                GroupBlock(:final groupId, :final items) => GroupRunTile(
                  key: ValueKey('group-$groupId'),
                  groupId: groupId,
                  label: groups[groupId]?.label,
                  items: items,
                  accent: accent,
                  costsByItem: costsByItem,
                  groupCosts: costsByGroup[groupId] ?? const [],
                  localeName: localeName,
                  onTapItem: onTapItem,
                  onTapCost: onTapCost,
                  onReorder: onReorderRun,
                  held: held,
                  onShowJourney: groupHasJourney(items, groupId)
                      ? () => showJourneyDetailsSheet(
                          context,
                          tripId: items.first.tripId,
                          groupId: groupId,
                          title: groups[groupId]?.label,
                        )
                      : null,
                  dragHandle: dragHandle,
                  isNow: index == happeningIndex,
                  nowMinutes: isToday ? nowMinutes : null,
                  nowLineMinutes: index == lineIndex ? nowMinutes : null,
                ),
                DecisionBlock() => AlternativeCard(
                  key: ValueKey('set-${block.set.id}'),
                  block: block,
                  isNow: index == happeningIndex,
                  nowLineMinutes: index == lineIndex ? nowMinutes : null,
                  nowMinutes: isToday ? nowMinutes : null,
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
                  onQuickAddPlace: (branchId, location) =>
                      onQuickAddPlace(day, location, alternativeId: branchId),
                  onReorderBranch: onReorderBranch,
                  onReorderRun: onReorderRun,
                  dragHandle: dragHandle,
                  held: held,
                  onPutDown: (branchId) =>
                      onPutDown(day, alternativeId: branchId),
                ),
              };
            },
          ),
        // The whole day is behind us: the line closes it off. (A day with nothing
        // planned never gets one — there is nothing to be past.)
        if (lineIndex == blocks.length && blocks.isNotEmpty)
          NowLine(minutes: nowMinutes),
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
              // Where something new goes is where a held entry can go too, so
              // the offer sits in the row already used for "put something here"
              // — and disappears entirely when nothing is held.
              if (held case final held?)
                PutDownChip(mode: held.mode, onPressed: () => onPutDown(day)),
            ],
          ),
        ),
      ],
    );
  }

  /// A loose item's tile. A grouped one is never drawn here — its run is one
  /// block, and [GroupRunTile] hands it its row.
  Widget _itemTile({
    required BuildContext context,
    required ItineraryItem item,
    required Widget dragHandle,
    required bool isNow,
    required int? nowLineMinutes,
  }) {
    return TimelineTile(
      key: ValueKey('item-${item.id}'),
      // An imported leg standing outside a group carries its own way into the
      // journey sheet; inside one the run's label carries it.
      onShowJourney: hasStandaloneJourney(item)
          ? () => showJourneyDetailsSheet(
              context,
              tripId: item.tripId,
              itemId: item.id,
            )
          : null,
      item: item,
      accent: accent,
      onTap: () => onTapItem(item),
      costs: costsByItem[item.id] ?? const [],
      localeName: localeName,
      onTapCost: onTapCost,
      dragHandle: dragHandle,
      isNow: isNow,
      nowLineMinutes: nowLineMinutes,
      held: isHeldItem(held, item),
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
