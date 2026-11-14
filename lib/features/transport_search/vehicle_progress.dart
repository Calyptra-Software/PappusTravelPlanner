import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/format/civil_date.dart';
import '../../data/database/app_database.dart';
import '../../data/database/stopovers.dart';
import '../itinerary/entry_times.dart';
import 'journey_map_features.dart' show nearestShapeIndex;

/// Where a leg's vehicle is believed to be, estimated from its timetable.
///
/// Nothing here asks the network: the position is read off the times the trip
/// holds, the plan plus the delays its last live-times refresh wrote, the way
/// the Transitous map estimates its vehicles from the timetable between two
/// answers. A vehicle stands at a stop from its arrival to its departure and
/// moves between two stops in proportion to the time, at an even pace along
/// the route it takes.
///
/// Pure, so where a train is at a given instant is testable without a clock, a
/// map or a widget.

/// Which part of its vehicle's run a call belongs to, seen from the leg.
enum CallPart {
  /// A stop before the one the traveler boards at.
  before,

  /// The stop the traveler boards at: the leg's start.
  board,

  /// A stop between the leg's ends.
  through,

  /// The stop the traveler gets off at: the leg's end.
  alight,

  /// A stop after the one the traveler gets off at.
  after;

  /// Whether the call is the leg's own: one of its ends or a stop between.
  bool get onLeg => this == board || this == through || this == alight;
}

/// One stop of a vehicle's run, with when it gets there and leaves again as
/// instants: the plan with the last known delay applied.
class RunCall {
  const RunCall({
    required this.name,
    required this.part,
    this.point,
    this.arrival,
    this.departure,
    this.cancelled = false,
  });

  final String name;
  final CallPart part;

  /// Where the stop is, when the trip knows.
  final LatLng? point;

  /// When the vehicle gets here; null where only its departure is known.
  final DateTime? arrival;

  /// When it leaves; null where only its arrival is known (the end of a run,
  /// or the end of a leg whose run beyond is not stored).
  final DateTime? departure;

  /// Whether the vehicle passes without calling here. Such a stop is listed
  /// but does not time the vehicle: it does not stand there.
  final bool cancelled;

  DateTime? get _arrives => arrival ?? departure;
  DateTime? get _leaves => departure ?? arrival;
}

/// The calls of [leg]'s vehicle, in the order it makes them: its run before
/// boarding (when stored), the leg's ends and the stops between, and its run
/// after getting off. Empty when the leg's own ends carry no time, since then
/// nothing can be placed on it.
///
/// The leg's ends are timed by its actual times where it has them, else its
/// planned ones; a stop by its planned departure moved by its delay, and its
/// arrival by its dwell before that. The first stop of a run is timed by its
/// departure only, the last of one by its arrival only, as they are stored.
///
/// Every time is read in the zone of its own stop. The leg's ends store none,
/// so they take the zone of the nearest stop that has one, and without any
/// the device's own, as a time from the router without one does
/// (`localParts`).
List<RunCall> legCalls(ItineraryItem leg) {
  final times = leg.times;
  final start = times.actualStart ?? times.plannedStart;
  final end = times.actualEnd ?? times.plannedEnd;
  if (start == null || end == null) return const [];
  final run = decodeRunStops(leg.runStops);
  final before = run?.before ?? const <Stopover>[];
  final after = run?.after ?? const <Stopover>[];

  final raw = <_RawCall>[
    for (final (i, stop) in before.indexed)
      _RawCall.stop(stop, CallPart.before, origin: i == 0),
    _RawCall(
      name: leg.fromLocation ?? '',
      part: CallPart.board,
      point: _point(leg.fromLat, leg.fromLon),
      departs: start,
    ),
    for (final stop in decodeStopovers(leg.stopovers))
      _RawCall.stop(stop, CallPart.through),
    _RawCall(
      name: leg.toLocation ?? '',
      part: CallPart.alight,
      point: _point(leg.toLat, leg.toLon),
      arrives: end,
    ),
    for (final (i, stop) in after.indexed)
      _RawCall.stop(stop, CallPart.after, terminus: i == after.length - 1),
  ];

  final zones = _zones(raw);
  return [
    for (final (i, call) in raw.indexed) call.resolve(leg.date, zones[i]),
  ];
}

/// The zone each call is read in: its own, else the nearest one's.
List<tz.Location?> _zones(List<_RawCall> calls) {
  final own = [for (final call in calls) _location(call.zone)];
  return [
    for (var i = 0; i < calls.length; i++) own[i] ?? _nearestZone(own, i),
  ];
}

tz.Location? _nearestZone(List<tz.Location?> zones, int at) {
  for (var d = 1; d < zones.length; d++) {
    for (final i in [at - d, at + d]) {
      if (i >= 0 && i < zones.length && zones[i] != null) return zones[i];
    }
  }
  return null;
}

tz.Location? _location(String? name) {
  if (name == null) return null;
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return null;
  }
}

/// A call as stored, before its times are made instants: minutes on the
/// leg's minute line (`entry_times.dart`), counted from midnight of the day
/// [dayOffset] days after the leg's date.
class _RawCall {
  const _RawCall({
    required this.name,
    required this.part,
    this.point,
    this.dayOffset = 0,
    this.arrives,
    this.departs,
    this.zone,
    this.cancelled = false,
  });

  factory _RawCall.stop(
    Stopover stop,
    CallPart part, {
    bool origin = false,
    bool terminus = false,
  }) {
    final live = stop.minutes + (stop.delayMinutes ?? 0);
    // The end of a run is stored by its arrival, having no departure; any
    // other stop by its departure, arriving its dwell before, except the
    // start of the run, which the vehicle only leaves.
    return _RawCall(
      name: stop.name,
      part: part,
      point: _point(stop.lat, stop.lon),
      dayOffset: stop.dayOffset,
      arrives: origin
          ? null
          : terminus
          ? live
          : live - (stop.dwellMinutes ?? 0),
      departs: terminus ? null : live,
      zone: stop.timeZone,
      cancelled: stop.cancelled,
    );
  }

  final String name;
  final CallPart part;
  final LatLng? point;
  final int dayOffset;
  final int? arrives;
  final int? departs;
  final String? zone;
  final bool cancelled;

  RunCall resolve(DateTime date, tz.Location? zone) {
    DateTime? at(int? minutes) =>
        minutes == null ? null : _instant(date, dayOffset, minutes, zone);
    return RunCall(
      name: name,
      part: part,
      point: point,
      arrival: at(arrives),
      departure: at(departs),
      cancelled: cancelled,
    );
  }
}

/// [minutes] on the minute line of the day [dayOffset] days after [date], as
/// an instant in [zone] (the device's where there is none). The day is moved
/// by calendar, never by a [Duration], so a 23-hour day cannot shift it.
DateTime _instant(
  DateTime date,
  int dayOffset,
  int minutes,
  tz.Location? zone,
) {
  final day = addDays(date, dayOffset + dayOfLine(minutes));
  final minute = minuteOfLine(minutes);
  final hour = minute ~/ 60;
  return zone == null
      ? DateTime(day.year, day.month, day.day, hour, minute % 60).toUtc()
      : tz.TZDateTime(
          zone,
          day.year,
          day.month,
          day.day,
          hour,
          minute % 60,
        ).toUtc();
}

LatLng? _point(double? lat, double? lon) =>
    lat == null || lon == null ? null : LatLng(lat, lon);

/// Where a vehicle is at an instant, as indices into its calls.
sealed class VehicleProgress {
  const VehicleProgress();
}

/// Standing at the call [index], between its arrival and its departure.
final class AtCall extends VehicleProgress {
  const AtCall(this.index);

  final int index;

  @override
  bool operator ==(Object other) => other is AtCall && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'AtCall($index)';
}

/// On the way from the call [from] to the call [to], [fraction] of the time
/// between leaving the one and reaching the other gone (0 to 1, the end
/// excluded). Calls between the two that are skipped lie on the way.
final class BetweenCalls extends VehicleProgress {
  const BetweenCalls(this.from, this.to, this.fraction);

  final int from;
  final int to;
  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is BetweenCalls &&
      other.from == from &&
      other.to == to &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(from, to, fraction);

  @override
  String toString() => 'BetweenCalls($from, $to, $fraction)';
}

/// Where the vehicle making [calls] is at [now], or null when it is not on
/// the part of its run that is known: it has not reached the first call yet,
/// or has left the last.
///
/// Only the calls [include] lets through are counted (all by default): the
/// list asks about the stops it shows, so a vehicle between two folded away
/// moves along the fold. A call that is skipped or carries no time is passed
/// over either way, since the vehicle does not stand there.
///
/// Times that run backwards (a delay known at one stop and not at the next)
/// are held at the latest one before them, so the vehicle waits rather than
/// jumping back.
VehicleProgress? progressAt(
  List<RunCall> calls,
  DateTime now, {
  bool Function(int index)? include,
}) {
  final stops = <({int index, DateTime arrives, DateTime leaves})>[];
  DateTime? last;
  for (final (i, call) in calls.indexed) {
    if (include != null && !include(i)) continue;
    var arrives = call._arrives;
    var leaves = call._leaves;
    if (call.cancelled || arrives == null || leaves == null) continue;
    if (last != null && arrives.isBefore(last)) arrives = last;
    if (leaves.isBefore(arrives)) leaves = arrives;
    stops.add((index: i, arrives: arrives, leaves: leaves));
    last = leaves;
  }
  if (stops.isEmpty || now.isBefore(stops.first.arrives)) return null;
  for (var k = 0; k < stops.length; k++) {
    final stop = stops[k];
    if (now.isBefore(stop.leaves)) return AtCall(stop.index);
    if (k + 1 == stops.length) break;
    final next = stops[k + 1];
    if (now.isBefore(next.arrives)) {
      final gone = now.difference(stop.leaves).inMilliseconds;
      final whole = next.arrives.difference(stop.leaves).inMilliseconds;
      return BetweenCalls(stop.index, next.index, gone / whole);
    }
  }
  return null;
}

/// Whether [progress] has the vehicle on the leg itself: at one of its calls,
/// or between two of them. What the traveler sits in while the leg is under
/// way, and what the map draws in the leg's color.
bool progressOnLeg(List<RunCall> calls, VehicleProgress progress) =>
    switch (progress) {
      AtCall(:final index) => calls[index].part.onLeg,
      BetweenCalls(:final from, :final to) =>
        calls[from].part.onLeg && calls[to].part.onLeg,
    };

/// How many stops the vehicle still calls at up to and including the one the
/// traveler boards at, while [progress] has it on its way there; null once it
/// has reached it, and when it is anywhere else.
int? stopsUntilBoarding(List<RunCall> calls, VehicleProgress progress) {
  final next = switch (progress) {
    AtCall(:final index) => index + 1,
    BetweenCalls(:final to) => to,
  };
  final board = calls.indexWhere((call) => call.part == CallPart.board);
  if (board < 0 || next > board) return null;
  if (progress case AtCall(:final index) when index == board) return null;
  var count = 0;
  for (var i = next; i <= board; i++) {
    if (!calls[i].cancelled) count++;
  }
  return count;
}

/// A route a vehicle travels, with its calls placed on it, so a position
/// between two calls can be put on the line rather than between the stops'
/// points.
///
/// Each call is placed on the route's point nearest to it, looked for only
/// after the call before was placed, so a route passing a station twice is
/// read in the order it is traveled. A call is placed only where [covers]
/// says the route reaches it: a leg's own route does not reach the stops of
/// its run before and after.
class VehicleRoute {
  factory VehicleRoute(
    List<RunCall> calls,
    List<LatLng> shape, {
    bool Function(RunCall call)? covers,
  }) {
    final at = List<int?>.filled(calls.length, null);
    var from = 0;
    if (shape.length > 1) {
      for (final (i, call) in calls.indexed) {
        final point = call.point;
        if (point == null || (covers != null && !covers(call))) continue;
        from = nearestShapeIndex(shape, point, from: from);
        at[i] = from;
      }
    }
    final along = List<double>.filled(shape.length, 0);
    for (var i = 1; i < shape.length; i++) {
      along[i] = along[i - 1] + _distance(shape[i - 1], shape[i]);
    }
    return VehicleRoute._(shape, at, along);
  }

  VehicleRoute._(this._shape, this._at, this._along);

  final List<LatLng> _shape;

  /// Where on the route each call lies, by index into it; null where it is
  /// not placed.
  final List<int?> _at;

  /// How far along the route each of its points is, in an equirectangular
  /// measure: only ever compared within one stretch of the route.
  final List<double> _along;

  /// Whether the call [index] has a place on the route: what to count when
  /// asking [progressAt] where a vehicle on it is.
  bool places(int index) => _at[index] != null;

  /// Where on the route [progress] puts the vehicle, or null when either call
  /// it lies between is not placed on it.
  LatLng? pointOf(VehicleProgress progress) {
    switch (progress) {
      case AtCall(:final index):
        final at = _at[index];
        return at == null ? null : _shape[at];
      case BetweenCalls(:final from, :final to, :final fraction):
        final a = _at[from];
        final b = _at[to];
        if (a == null || b == null || b < a) return null;
        if (a == b) return _shape[a];
        final target = _along[a] + fraction * (_along[b] - _along[a]);
        var i = a;
        while (i + 1 < b && _along[i + 1] <= target) {
          i++;
        }
        final span = _along[i + 1] - _along[i];
        final t = span == 0 ? 0.0 : (target - _along[i]) / span;
        final p = _shape[i];
        final q = _shape[i + 1];
        return LatLng(
          p.latitude + t * (q.latitude - p.latitude),
          p.longitude + t * (q.longitude - p.longitude),
        );
    }
  }
}

double _distance(LatLng a, LatLng b) {
  final scale = math.cos((a.latitude + b.latitude) * math.pi / 360);
  final dLat = b.latitude - a.latitude;
  final dLon = (b.longitude - a.longitude) * scale;
  return math.sqrt(dLat * dLat + dLon * dLon);
}
