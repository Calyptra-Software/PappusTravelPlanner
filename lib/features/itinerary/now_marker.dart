import '../../data/database/app_database.dart';
import 'day_blocks.dart';

/// Where the current time falls in a day — the "you are here" mark on the
/// timeline.
///
/// A day is an ordered *list*, not a time-scaled axis: times are optional, so
/// there is no vertical scale to offset a now-line into. What can be said is
/// which entry is under way, and, failing that, which entries are already behind
/// us. Pure (like `day_blocks.dart` and `live_items.dart`), so the placement is
/// unit-testable without a widget tree or a clock.

/// The stretch of a day an entry covers, as minutes since midnight. [end] is
/// never before [start]; the two are equal for an entry that is a moment (only a
/// start time, or a start and end alike) rather than a span.
typedef TimeSpan = ({int start, int end});

/// Where "now" sits among a list of blocks (or of items).
final class NowMarker {
  const NowMarker({required this.index, required this.happening});

  /// When [happening], the entry at [index] is under way. Otherwise this is the
  /// boundary between what is behind us and what is still ahead: the now-line is
  /// drawn *above* the entry at [index], and [index] == the list's length means
  /// everything is behind us and the line goes at the bottom.
  final int index;
  final bool happening;

  @override
  bool operator ==(Object other) =>
      other is NowMarker &&
      other.index == index &&
      other.happening == happening;

  @override
  int get hashCode => Object.hash(index, happening);

  @override
  String toString() => 'NowMarker(index: $index, happening: $happening)';
}

/// The span [item] covers, or null when it carries no time at all. An entry with
/// only one of the two times is a moment at that time.
///
/// An actual time outranks the planned one it was recorded against: it is what
/// happened, and "you are here" is a claim about the day as it is going, not as
/// it was meant to go. Each end is taken on its own — a leg that left late but
/// has not arrived yet is running from its actual departure to its planned
/// arrival.
TimeSpan? itemSpan(ItineraryItem item) {
  final from = item.actualStartMinutes ?? item.startMinutes;
  final to = item.actualEndMinutes ?? item.endMinutes;
  final start = from ?? to;
  if (start == null) return null;
  final end = to ?? start;
  return (start: start, end: end < start ? start : end);
}

/// The span a whole block covers: for a run, its members' hull — a journey of
/// several legs is under way from the first departure to the last arrival, the
/// changes in between included; for a decision, the span of its **chosen**
/// option — the plan as it stands is what the trip is actually doing, so an
/// option not taken can never be what is happening now.
TimeSpan? blockSpan(DayBlock block) {
  final items = switch (block) {
    ItemBlock(:final item) => [item],
    GroupBlock(:final items) => items,
    DecisionBlock(:final chosen, :final itemsByBranch) =>
      itemsByBranch[chosen.id] ?? const <ItineraryItem>[],
  };
  return _union(items);
}

/// Where now sits among a day's blocks. Null when the day carries no times at
/// all — there is then nothing to anchor a mark to, and the day header's clock
/// says all that can be said.
NowMarker? nowMarker(List<DayBlock> blocks, int nowMinutes) =>
    _marker([for (final block in blocks) blockSpan(block)], nowMinutes);

/// Where now sits among a plain list of items — one option's contents.
NowMarker? nowMarkerForItems(List<ItineraryItem> items, int nowMinutes) =>
    _marker([for (final item in items) itemSpan(item)], nowMinutes);

/// The spans' hull: from the earliest start to the latest end.
TimeSpan? _union(List<ItineraryItem> items) {
  int? start;
  int? end;
  for (final item in items) {
    final span = itemSpan(item);
    if (span == null) continue;
    if (start == null || span.start < start) start = span.start;
    if (end == null || span.end > end) end = span.end;
  }
  if (start == null || end == null) return null;
  return (start: start, end: end);
}

/// The placement rule, over the spans of a list whose entries may be untimed
/// (null spans).
///
/// An entry is *under way* when now falls inside a real span — a moment (start
/// == end) can be passed but never inhabited. Otherwise the line goes after the
/// last entry that is behind us, which leaves an untimed entry ahead of the line
/// unless something timed after it has already been passed: we cannot know when
/// an untimed entry happens, and claiming it is done is the guess that would
/// make the mark lie.
NowMarker? _marker(List<TimeSpan?> spans, int nowMinutes) {
  var lastPast = -1;
  var anyTimed = false;
  for (var i = 0; i < spans.length; i++) {
    final span = spans[i];
    if (span == null) continue;
    anyTimed = true;
    if (span.end > span.start &&
        nowMinutes >= span.start &&
        nowMinutes < span.end) {
      return NowMarker(index: i, happening: true);
    }
    if (span.end <= nowMinutes) lastPast = i;
  }
  if (!anyTimed) return null;
  return NowMarker(index: lastPast + 1, happening: false);
}
