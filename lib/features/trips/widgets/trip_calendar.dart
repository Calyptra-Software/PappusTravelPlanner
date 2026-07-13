import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/format/date_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../calendar_layout.dart';
import 'trip_card.dart';

/// Month-grid calendar of trips. Each trip is a horizontal bar in its accent
/// colour spanning its days; tapping a bar opens that trip. Undated trips can't
/// be placed on the grid and are surfaced only as a count badge in the header.
class TripCalendar extends StatefulWidget {
  const TripCalendar({
    super.key,
    required this.trips,
    required this.totals,
    required this.onOpenTrip,
  });

  /// The (already filtered) trips to render, dated and undated alike.
  final List<Trip> trips;
  final Map<int, Map<Currency, int>> totals;
  final void Function(Trip trip) onOpenTrip;

  @override
  State<TripCalendar> createState() => _TripCalendarState();
}

class _TripCalendarState extends State<TripCalendar> {
  static const _maxVisibleLanes = 3;
  static const _barHeight = 18.0;
  static const _laneGap = 3.0;
  static const _initialPage = 1200; // ~100 years of scroll either way

  late final PageController _controller = PageController(
    initialPage: _initialPage,
  );
  late final DateTime _anchor = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  late DateTime _visibleMonth = _anchor;

  DateTime _monthForPage(int page) =>
      DateTime(_anchor.year, _anchor.month + (page - _initialPage));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToToday() {
    _controller.animateToPage(
      _initialPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).languageCode;
    final undated = widget.trips.where((t) => tripSpan(t) == null).length;

    return Column(
      children: [
        _MonthHeader(
          month: _visibleMonth,
          localeName: localeName,
          undatedCount: undated,
          onPrev: () => _controller.previousPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          ),
          onNext: () => _controller.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          ),
          onToday: _jumpToToday,
          onShowUndated: undated == 0 ? null : () => _showUndated(context),
        ),
        _WeekdayHeader(localeName: localeName),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (page) =>
                setState(() => _visibleMonth = _monthForPage(page)),
            itemBuilder: (context, page) => _MonthGrid(
              month: _monthForPage(page),
              trips: widget.trips,
              maxVisibleLanes: _maxVisibleLanes,
              barHeight: _barHeight,
              laneGap: _laneGap,
              onOpenTrip: widget.onOpenTrip,
              onShowDay: (day, dayTrips) =>
                  _showDay(context, day, dayTrips, localeName),
            ),
          ),
        ),
      ],
    );
  }

  void _showUndated(BuildContext context) {
    final undated = widget.trips.where((t) => tripSpan(t) == null).toList();
    _openTripSheet(
      context,
      title: AppLocalizations.of(context).calendarUndatedTitle,
      trips: undated,
    );
  }

  void _showDay(
    BuildContext context,
    DateTime day,
    List<Trip> dayTrips,
    String localeName,
  ) {
    _openTripSheet(
      context,
      title: formatFullDate(day, localeName),
      trips: dayTrips,
    );
  }

  void _openTripSheet(
    BuildContext context, {
    required String title,
    required List<Trip> trips,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final trip in trips) ...[
              TripCard(
                trip: trip,
                totals: widget.totals[trip.id] ?? const {},
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onOpenTrip(trip);
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.localeName,
    required this.undatedCount,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onShowUndated,
  });

  final DateTime month;
  final String localeName;
  final int undatedCount;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback? onShowUndated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = DateFormat.yMMMM(localeName).format(month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.calendarPreviousMonth,
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (undatedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.event_busy_outlined, size: 18),
                label: Text('$undatedCount'),
                tooltip: l10n.calendarUndatedTooltip,
                onPressed: onShowUndated,
              ),
            ),
          TextButton(onPressed: onToday, child: Text(l10n.calendarToday)),
          IconButton(
            tooltip: l10n.calendarNextMonth,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.localeName});

  final String localeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstWeekday = MaterialLocalizations.of(
      context,
    ).firstDayOfWeekIndex; // 0=Sun
    final symbols = DateFormat('', localeName).dateSymbols.SHORTWEEKDAYS;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                symbols[(firstWeekday + i) % 7],
                textAlign: TextAlign.center,
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.trips,
    required this.maxVisibleLanes,
    required this.barHeight,
    required this.laneGap,
    required this.onOpenTrip,
    required this.onShowDay,
  });

  final DateTime month;
  final List<Trip> trips;
  final int maxVisibleLanes;
  final double barHeight;
  final double laneGap;
  final void Function(Trip trip) onOpenTrip;
  final void Function(DateTime day, List<Trip> dayTrips) onShowDay;

  /// The dated trips covering [day], newest span first, for a day's sheet.
  List<Trip> _tripsOn(DateTime day) {
    final d = normalizeDay(day);
    final result = <Trip>[];
    for (final trip in trips) {
      final span = tripSpan(trip);
      if (span == null) continue;
      if (!d.isBefore(span.start) && !d.isAfter(span.end)) result.add(trip);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final weeks = buildMonthGrid(month, trips, firstWeekday);
    return Padding(
      // Bottom clearance so the "New trip" FAB doesn't cover the last week.
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 72),
      child: Column(
        children: [
          for (final week in weeks)
            Expanded(
              child: _WeekRow(
                week: week,
                month: month,
                maxVisibleLanes: maxVisibleLanes,
                barHeight: barHeight,
                laneGap: laneGap,
                onOpenTrip: onOpenTrip,
                onTapDay: (day) {
                  final dayTrips = _tripsOn(day);
                  if (dayTrips.isNotEmpty) onShowDay(day, dayTrips);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.week,
    required this.month,
    required this.maxVisibleLanes,
    required this.barHeight,
    required this.laneGap,
    required this.onOpenTrip,
    required this.onTapDay,
  });

  final CalendarWeek week;
  final DateTime month;
  final int maxVisibleLanes;
  final double barHeight;
  final double laneGap;
  final void Function(Trip trip) onOpenTrip;
  final void Function(DateTime day) onTapDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = normalizeDay(DateTime.now());
    final visibleLanes = week.laneCount > maxVisibleLanes
        ? maxVisibleLanes -
              1 // reserve a lane for the "+N more" markers
        : week.laneCount;
    final overflow = week.laneCount > maxVisibleLanes
        ? overflowByColumn(week, visibleLanes)
        : List<int>.filled(7, 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        return Stack(
          children: [
            // Day-number headers and tap targets.
            Row(
              children: [
                for (final day in week.days)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTapDay(day),
                      child: _DayCell(
                        day: day,
                        inMonth: day.month == month.month,
                        isToday: normalizeDay(day) == today,
                      ),
                    ),
                  ),
              ],
            ),
            // Trip bars, positioned over the day cells below the numbers.
            for (final span in week.spans)
              if (span.lane < visibleLanes)
                Positioned(
                  left: span.startCol * cellWidth + 1.5,
                  width: span.columnSpan * cellWidth - 3,
                  top: 26 + span.lane * (barHeight + laneGap),
                  height: barHeight,
                  child: _TripBar(
                    span: span,
                    onTap: () => onOpenTrip(span.trip),
                  ),
                ),
            // "+N more" markers for columns whose trips overflowed the lanes.
            for (var col = 0; col < 7; col++)
              if (overflow[col] > 0)
                Positioned(
                  left: col * cellWidth,
                  width: cellWidth,
                  top: 26 + visibleLanes * (barHeight + laneGap),
                  child: Text(
                    '+${overflow[col]}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = isToday
        ? scheme.onPrimary
        : inMonth
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: 24,
          height: 22,
          alignment: Alignment.center,
          decoration: isToday
              ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
              : null,
          child: Text(
            '${day.day}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TripBar extends StatelessWidget {
  const _TripBar({required this.span, required this.onTap});

  final CalendarSpan span;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Color(span.trip.colorValue);
    // Legible label colour regardless of the accent's brightness.
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    const rounded = Radius.circular(6);
    const flat = Radius.zero;
    final radius = BorderRadius.horizontal(
      left: span.continuesLeft ? flat : rounded,
      right: span.continuesRight ? flat : rounded,
    );
    // Only label the bar where its title actually begins.
    final showLabel = !span.continuesLeft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: accent, borderRadius: radius),
          child: showLabel
              ? Text(
                  span.trip.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
