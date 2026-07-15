import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// Statistics derived from a trip's transport legs, split out as pure functions
/// (like `trip_stats.dart`) so the aggregation is unit-testable without a
/// database. Legs are bucketed by [TransportMode]; each mode carries how many
/// legs used it and how much time they add up to — kept both as **planned** and
/// as **actual**, the app's two time axes, so the two can be compared. Only the
/// trip's *live* legs should be passed in — see `live_items.dart` — so an
/// unchosen alternative never counts, exactly as it doesn't for the money.

/// One transport mode's slice of a trip, holding the planned and actual figures
/// side by side.
class TransportModeStat {
  const TransportModeStat({
    required this.mode,
    required this.legs,
    required this.plannedMinutes,
    required this.actualCount,
    required this.actualMinutes,
  });

  final TransportMode mode;

  /// Number of legs using this mode. Every leg is part of the plan, so this is
  /// also the *planned* leg count.
  final int legs;

  /// Summed planned duration of the mode's legs, in minutes — balanced across
  /// the whole trip so a journey split around an unplanned stop (a start-only
  /// leg and an end-only leg) still counts, and so a leg that runs past midnight
  /// counts its real span. See [computeTransportStats].
  final int plannedMinutes;

  /// How many of the legs have anything recorded on the *actual* axis (a real
  /// departure or arrival) — the ones that actually happened, as far as the trip
  /// has logged. May be fewer than [legs] while a trip is still under way.
  final int actualCount;

  /// Summed actual duration, in minutes — the counterpart to [plannedMinutes],
  /// measured the same way over the recorded times.
  final int actualMinutes;
}

/// Per-mode transport statistics for a whole trip, most-used mode first.
class TransportStats {
  const TransportStats(this.byMode);

  /// Modes that actually occur, sorted by leg count (then planned time) desc.
  final List<TransportModeStat> byMode;

  bool get isEmpty => byMode.isEmpty;

  int get totalLegs => byMode.fold(0, (sum, m) => sum + m.legs);
  int get totalPlannedMinutes =>
      byMode.fold(0, (sum, m) => sum + m.plannedMinutes);
  int get totalActualCount => byMode.fold(0, (sum, m) => sum + m.actualCount);
  int get totalActualMinutes =>
      byMode.fold(0, (sum, m) => sum + m.actualMinutes);
}

/// Computes [TransportStats] from a trip's [items]. Non-transport entries and
/// transport legs with no [ItineraryItem.mode] set are ignored (an unassigned
/// mode can't be attributed to any bucket).
///
/// Each axis (planned, actual) is measured independently and balanced per mode
/// across the **whole trip**: see [_axisMinutes]. This makes two otherwise
/// awkward shapes come out right — a journey split around an unplanned stop into
/// a start-only leg and an end-only leg, and a single leg that departs one
/// evening and arrives the next morning.
TransportStats computeTransportStats(List<ItineraryItem> items) {
  final legs = <TransportMode, int>{};
  final actualCount = <TransportMode, int>{};
  final planned = <TransportMode, List<_Span>>{};
  final actual = <TransportMode, List<_Span>>{};

  for (final item in items) {
    if (item.kind != ItemKind.transport) continue;
    final mode = item.mode;
    if (mode == null) continue;
    legs.update(mode, (v) => v + 1, ifAbsent: () => 1);
    actualCount.putIfAbsent(mode, () => 0);
    final day = _dayIndex(item.date);

    planned
        .putIfAbsent(mode, () => [])
        .add(_Span(day, item.startMinutes, item.endMinutes));

    if (item.actualStartMinutes != null || item.actualEndMinutes != null) {
      actualCount.update(mode, (v) => v + 1);
    }
    actual
        .putIfAbsent(mode, () => [])
        .add(_Span(day, item.actualStartMinutes, item.actualEndMinutes));
  }

  final byMode =
      legs.entries
          .map(
            (e) => TransportModeStat(
              mode: e.key,
              legs: e.value,
              plannedMinutes: _axisMinutes(planned[e.key]!),
              actualCount: actualCount[e.key]!,
              actualMinutes: _axisMinutes(actual[e.key]!),
            ),
          )
          .toList()
        ..sort(_byUsage);
  return TransportStats(byMode);
}

/// Merges several trips' [TransportStats] into one by summing each mode's legs
/// and time — the all-trips overview. Each trip is aggregated (and its time
/// balanced) on its own first via [computeTransportStats], so a journey split
/// within a trip stays balanced there and can't pair across trips; this only
/// adds the per-mode totals up.
TransportStats mergeTransportStats(Iterable<TransportStats> perTrip) {
  final legs = <TransportMode, int>{};
  final planned = <TransportMode, int>{};
  final actualCount = <TransportMode, int>{};
  final actual = <TransportMode, int>{};
  for (final stats in perTrip) {
    for (final m in stats.byMode) {
      legs.update(m.mode, (v) => v + m.legs, ifAbsent: () => m.legs);
      planned.update(
        m.mode,
        (v) => v + m.plannedMinutes,
        ifAbsent: () => m.plannedMinutes,
      );
      actualCount.update(
        m.mode,
        (v) => v + m.actualCount,
        ifAbsent: () => m.actualCount,
      );
      actual.update(
        m.mode,
        (v) => v + m.actualMinutes,
        ifAbsent: () => m.actualMinutes,
      );
    }
  }

  final byMode =
      legs.entries
          .map(
            (e) => TransportModeStat(
              mode: e.key,
              legs: e.value,
              plannedMinutes: planned[e.key]!,
              actualCount: actualCount[e.key]!,
              actualMinutes: actual[e.key]!,
            ),
          )
          .toList()
        ..sort(_byUsage);
  return TransportStats(byMode);
}

/// Orders modes by leg count, then planned time, then stable enum order.
int _byUsage(TransportModeStat a, TransportModeStat b) {
  final byLegs = b.legs.compareTo(a.legs);
  if (byLegs != 0) return byLegs;
  final byTime = b.plannedMinutes.compareTo(a.plannedMinutes);
  if (byTime != 0) return byTime;
  return a.mode.index.compareTo(b.mode.index);
}

/// One leg's span on a single axis: its [day] (an absolute day index) plus the
/// [start] and [end] minutes-since-midnight on that axis, either of which may be
/// null.
class _Span {
  const _Span(this.day, this.start, this.end);
  final int day;
  final int? start;
  final int? end;
}

/// Total minutes a mode spent in transit on one axis, given each leg's [spans].
///
/// Every endpoint is placed on an absolute minute line (`day * 1440 + minute`),
/// and a leg whose end falls before its start is read as running past midnight
/// (its end shifts to the next day). When starts and ends balance — the usual
/// case, and the case a stop-split produces, where a start-only leg's departure
/// pairs with an end-only leg's arrival — the total is simply Σ(ends) − Σ(starts)
/// across the mode, so the missing middle drops out. When they don't balance
/// (a genuinely open leg with no counterpart), only fully-timed legs are summed,
/// so an unfinished leg contributes nothing rather than a bogus span.
int _axisMinutes(List<_Span> spans) {
  final starts = <int>[];
  final ends = <int>[];
  var closedSum = 0;
  for (final s in spans) {
    final absStart = s.start == null ? null : s.day * 1440 + s.start!;
    var absEnd = s.end == null ? null : s.day * 1440 + s.end!;
    if (s.start != null && s.end != null && s.end! < s.start!) {
      absEnd = absEnd! + 1440; // Departed one day, arrived the next.
    }
    if (absStart != null) starts.add(absStart);
    if (absEnd != null) ends.add(absEnd);
    if (absStart != null && absEnd != null) closedSum += absEnd - absStart;
  }

  final total = starts.length == ends.length
      ? ends.fold<int>(0, (a, b) => a + b) -
            starts.fold<int>(0, (a, b) => a + b)
      : closedSum;
  return total < 0 ? 0 : total;
}

/// An absolute day index for [date] (already midnight-normalized). Uses a UTC
/// midnight so the count is unaffected by daylight-saving shifts.
int _dayIndex(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
