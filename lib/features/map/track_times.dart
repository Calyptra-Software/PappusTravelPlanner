import 'package:latlong2/latlong.dart';

import '../../core/format/civil_date.dart';
import '../../data/database/app_database.dart';
import '../itinerary/entry_times.dart';
import 'track_import_plan.dart' show TrackEnd;

/// What a recording's timestamps say about the entries it is divided among.
///
/// Two things, both read once during the import and neither stored: **which
/// days** the recording was made on, so a file from the wrong outing is noticed
/// before it is cut up; and **when each leg actually began and ended**, offered
/// as the leg's actual times. Pure, like the division itself (`track_split.dart`).
///
/// The one thing this file cannot know is the zone. A GPX file stores UTC and
/// the app stores wall-clock times with no zone at all, so every conversion
/// here takes an [Duration] offset the user can see and change on the import
/// screen. The device's own offset is only its first answer
/// ([defaultRecordingOffset]) — right for an import made where the trip
/// happened, and wrong by exactly the difference for one made at home
/// afterwards, which is why it is shown rather than assumed.

const Distance _distance = Distance(calculator: Haversine());

/// How close to a point the recording has to stay to count as **not yet
/// having left it** — or as having already arrived.
///
/// A heuristic, and stated as one. A handover is one point of the line, but a
/// change of trains is ten minutes of standing on a platform: the leg before
/// arrived when the device first came within this distance of the handover, and
/// the leg after left when it last was. 50 m holds a platform and the jitter of
/// a fix under a station roof, while a walk at 5 km/h is out of it in under a
/// minute.
const double kStationaryRadiusMeters = 50;

/// A recorded time and an entered one closer than this say the same thing, so
/// the import does not ask about them: a recording has seconds, the entry
/// minutes, and the two are rounded at different moments.
const int kSameTimeToleranceMinutes = 2;

/// The device's offset from UTC at [instant] — the zone the import screen
/// starts from. At the instant rather than now, so a recording made in summer
/// and imported in winter still gets its summer offset.
Duration defaultRecordingOffset(DateTime instant) =>
    instant.toLocal().timeZoneOffset;

/// [utc] as the wall clock at [offset] shows it.
///
/// Returned as a [DateTime.utc] whose fields *are* that wall-clock time — a
/// floating time, which is what the app stores. Not a local [DateTime]: those
/// carry the device's daylight-saving rules, and adding a minute to one across
/// a change lands on the wrong hour.
DateTime wallClock(DateTime utc, Duration offset) => utc.toUtc().add(offset);

/// The calendar days a recording from [first] to [last] touches, read at
/// [offset], or null when the recording carries no times.
({DateTime from, DateTime to})? recordingDays(
  DateTime? first,
  DateTime? last,
  Duration offset,
) {
  if (first == null || last == null) return null;
  final from = wallClock(first, offset);
  final to = wallClock(last, offset);
  return (
    from: DateTime(from.year, from.month, from.day),
    to: DateTime(to.year, to.month, to.day),
  );
}

/// Whether the recording shares no day with [entries] — the warning shown
/// before a walk from May is cut up across a trip in June.
///
/// The days an entry covers include the morning an overnight leg arrives on
/// (`daysCovered`), so a night train's recording is never told it is from the
/// wrong day. A warning, not a refusal: attaching last week's scouting walk to
/// tomorrow's plan is a reasonable thing to do on purpose.
bool recordingOnOtherDays(
  ({DateTime from, DateTime to}) recorded,
  List<ItineraryItem> entries,
) {
  if (entries.isEmpty) return false;
  for (final entry in entries) {
    for (final day in daysCovered(entry.date, entry.endDayOffset)) {
      if (daysBetween(recorded.from, day) >= 0 &&
          daysBetween(day, recorded.to) >= 0) {
        return false;
      }
    }
  }
  return true;
}

/// When each stretch of a divided recording was left and reached, as UTC
/// instants, or null where the recording has no time there.
///
/// [cuts] are the handovers as indices into [points] (`trackCutIndices`), so
/// leg `i` runs from `cuts[i - 1]` (or the first point) to `cuts[i]` (or the
/// last). A leg **departs** at the last point still within
/// [kStationaryRadiusMeters] of where its stretch starts and **arrives** at the
/// first point within it of where its stretch ends — so the time spent standing
/// at a handover, or at the start before walking off, belongs to neither leg.
/// Each search stays inside the leg's own stretch; a stretch that never leaves
/// that radius at all is read at its raw ends instead, since the two searches
/// would otherwise cross and have the leg arrive before it left.
List<({DateTime? departed, DateTime? arrived})> legInstants(
  List<LatLng> points,
  List<DateTime?> times,
  List<int> cuts, {
  double radius = kStationaryRadiusMeters,
}) {
  final out = <({DateTime? departed, DateTime? arrived})>[];
  if (points.length < 2 || times.length != points.length) return out;
  for (var leg = 0; leg <= cuts.length; leg++) {
    final first = leg == 0 ? 0 : cuts[leg - 1];
    final last = leg == cuts.length ? points.length - 1 : cuts[leg];

    var left = first;
    while (left + 1 <= last &&
        _distance.as(LengthUnit.Meter, points[left + 1], points[first]) <=
            radius) {
      left++;
    }
    var reached = last;
    while (reached - 1 >= first &&
        _distance.as(LengthUnit.Meter, points[reached - 1], points[last]) <=
            radius) {
      reached--;
    }
    if (left > reached) {
      left = first;
      reached = last;
    }
    out.add((departed: times[left], arrived: times[reached]));
  }
  return out;
}

/// One actual time the import offers to write.
class ActualTimeProposal {
  const ActualTimeProposal({
    required this.item,
    required this.end,
    required this.minutes,
  });

  /// The leg it belongs to.
  final ItineraryItem item;

  /// [TrackEnd.from] for the actual departure, [TrackEnd.to] for the arrival.
  final TrackEnd end;

  /// What would be written: minutes since midnight, as the column stores them.
  final int minutes;

  /// What the leg already holds there, or null when the field is empty.
  int? get existing =>
      end == TrackEnd.from ? item.actualStartMinutes : item.actualEndMinutes;

  /// Offered ticked only where nothing was entered: a time somebody typed in,
  /// or one the live data filled, is a statement the file may be a witness
  /// against but does not get to overrule by default.
  bool get selectedByDefault => existing == null;
}

/// The actual times the recording can supply for [legs], given
/// [instants] from [legInstants] read at [offset].
///
/// Leaves out, in order:
///
/// * an end the recording has **no time** for;
/// * one that would **not read back as the same moment** — the app stores a
///   time of day and finds its day by the rule in `entry_times.dart`, so a
///   recording from another day, or one more than twelve hours from the plan,
///   would be written as a plausible time on the wrong day. Written only where
///   storing it and reading it again lands on the minute it was measured at;
/// * one that would put the leg's end **before its start** against an actual
///   time already entered on its other end;
/// * one **within [kSameTimeToleranceMinutes]** of what is already there,
///   which is the recording agreeing and nothing to ask about.
List<ActualTimeProposal> actualTimeProposals(
  List<ItineraryItem> legs,
  List<({DateTime? departed, DateTime? arrived})> instants,
  Duration offset,
) {
  final out = <ActualTimeProposal>[];
  for (var i = 0; i < legs.length && i < instants.length; i++) {
    final leg = legs[i];
    final times = leg.times;
    final departed = _onLine(instants[i].departed, leg.date, offset);
    final arrived = _onLine(instants[i].arrived, leg.date, offset);

    if (departed != null) {
      final read = entryTimes(
        startMinutes: leg.startMinutes,
        endMinutes: leg.endMinutes,
        endDayOffset: leg.endDayOffset,
        actualStartMinutes: minuteOfLine(departed),
      ).actualStart;
      final against = times.actualEnd;
      if (read == departed &&
          (against == null || against >= departed) &&
          !_agrees(times.actualStart, departed)) {
        out.add(
          ActualTimeProposal(
            item: leg,
            end: TrackEnd.from,
            minutes: minuteOfLine(departed),
          ),
        );
      }
    }
    if (arrived != null) {
      final read = entryTimes(
        startMinutes: leg.startMinutes,
        endMinutes: leg.endMinutes,
        endDayOffset: leg.endDayOffset,
        actualEndMinutes: minuteOfLine(arrived),
      ).actualEnd;
      final against = times.actualStart;
      if (read == arrived &&
          (against == null || against <= arrived) &&
          !_agrees(times.actualEnd, arrived)) {
        out.add(
          ActualTimeProposal(
            item: leg,
            end: TrackEnd.to,
            minutes: minuteOfLine(arrived),
          ),
        );
      }
    }
  }
  return out;
}

/// [instant] on the minute line of an entry dated [date], rounded to the
/// minute — or null for no instant.
int? _onLine(DateTime? instant, DateTime date, Duration offset) {
  if (instant == null) return null;
  final wall = wallClock(instant, offset).add(const Duration(seconds: 30));
  return daysBetween(date, wall) * kMinutesPerDay +
      wall.hour * 60 +
      wall.minute;
}

bool _agrees(int? existing, int measured) =>
    existing != null && (existing - measured).abs() < kSameTimeToleranceMinutes;
