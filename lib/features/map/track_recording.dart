import 'dart:math' show max;

import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import 'map_features.dart' show lineLength;

/// What this app's own recorder keeps of the receiver's readings, and how what
/// it kept becomes the lines the track import divides.
///
/// Pure, like the rest of what the map reads (`track_split.dart`,
/// `track_times.dart`): the recorder decides nothing that these functions do
/// not, so every rule here can be tested without a receiver.
///
/// What is **not** done is as deliberate as what is. Nothing is smoothed,
/// simplified or snapped to a road: a recording is the record of where the
/// device said it was, and a line that has been made to look nicer is a line
/// that no longer says that. Deciding whether a reading is worth keeping is not
/// the same act — a fix forty meters off, or a jitter of three meters while
/// standing on a platform, says nothing about where anybody went.

const Distance _distance = Distance(calculator: Haversine());

/// A fix less sure of itself than this is not kept.
///
/// The radius is the platform's own 68 % estimate. Outdoors a receiver reports
/// a few meters, under trees or between buildings a few tens; past 50 m a
/// reading is usually a network fix standing in for a satellite one, which
/// would put a corner into the line that nobody walked. A heuristic, named as
/// one.
const double kMaxRecordingAccuracyMeters = 50;

/// The least a fix has to move from the last one kept to be kept itself.
///
/// The floor under the rule in [acceptFix], for a receiver that reports a
/// sharper fix than it has — standing still, a position wanders by a few
/// meters even then.
const double kMinRecordingStepMeters = 5;

/// One reading of the receiver, as the recorder is handed it.
final class FixReading {
  const FixReading({
    required this.position,
    required this.accuracyMeters,
    required this.at,
  });

  final LatLng position;

  /// The platform's 68 % confidence radius, in meters.
  final double accuracyMeters;

  /// When the fix was taken.
  final DateTime at;
}

/// Whether [candidate] is worth keeping, after [last] — the last fix kept in
/// the same stretch of the recording, or null at the start of one.
///
/// Three conditions, each answering a different way a reading can say nothing:
///
/// * **Sure enough of itself**, by [kMaxRecordingAccuracyMeters]. A radius the
///   platform could not give a finite figure for counts as no figure.
/// * **Later than the last one.** The import reads a line's times only when
///   none of them runs backwards (`GpxTrack.times`), and a single reading
///   delivered out of order would cost the whole recording its times.
/// * **Further from the last one than either the floor or its own
///   uncertainty.** Movement smaller than the radius is indistinguishable from
///   the fix wandering, so a reading that close is not evidence of a step. It
///   also means a stop produces no readings at all, which is what the import
///   wants: a change of trains is where the line *stays*
///   (`kStationaryRadiusMeters`), and the next reading is the one that leaves.
///
/// The first fix of a stretch only has to be sure enough — there is nothing to
/// have moved from.
bool acceptFix(FixReading? last, FixReading candidate) {
  final accuracy = candidate.accuracyMeters;
  if (!accuracy.isFinite || accuracy > kMaxRecordingAccuracyMeters) {
    return false;
  }
  if (last == null) return true;
  if (!candidate.at.isAfter(last.at)) return false;
  final step = _distance.as(
    LengthUnit.Meter,
    last.position,
    candidate.position,
  );
  return step >= max(accuracy, kMinRecordingStepMeters);
}

/// One stretch of a recording, as the track import takes it: the points, and
/// when each was taken, as UTC instants and parallel to them.
typedef RecordedLine = ({List<LatLng> points, List<DateTime> times});

/// The stored [fixes] of one recording as the lines the import divides — one
/// per segment, in the order they were taken.
///
/// [fixes] is expected in the order `RecordingDao.fixesOf` returns, which is
/// the order they were written. A segment is never joined to the next: the
/// gap between them is a pause, or the app having been stopped, and drawing a
/// line across it would claim ground nobody covered. A segment holding fewer
/// than two fixes is not a line and is left out, and a fix no later than the
/// one before it is dropped: [acceptFix] promises times that move forward only
/// within one session of the recorder, and one stray reading must not cost the
/// whole line its times.
List<RecordedLine> recordedLines(List<RecordingFix> fixes) {
  final lines = <RecordedLine>[];
  var points = <LatLng>[];
  var times = <DateTime>[];
  int? segment;

  void close() {
    if (points.length >= 2) lines.add((points: points, times: times));
    points = <LatLng>[];
    times = <DateTime>[];
  }

  for (final fix in fixes) {
    if (fix.segment != segment) {
      close();
      segment = fix.segment;
    }
    final at = DateTime.fromMillisecondsSinceEpoch(fix.recordedAt, isUtc: true);
    if (times.isNotEmpty && !at.isAfter(times.last)) continue;
    points.add(LatLng(fix.lat, fix.lon));
    times.add(at);
  }
  close();
  return lines;
}

/// How far the [lines] of a recording run together, in meters — never across
/// the gap between two of them.
double recordedDistanceMeters(List<RecordedLine> lines) {
  var total = 0.0;
  for (final line in lines) {
    total += lineLength(line.points);
  }
  return total;
}
