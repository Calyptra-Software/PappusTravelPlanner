/// What a trip looks like on a map, derived from its itinerary entries.
///
/// Pure (like `day_blocks.dart`, `live_items.dart` and `now_marker.dart`), so
/// the rules below are unit-testable without a widget tree or a tile server —
/// and so the map draws from the same reading of the plan the timeline does
/// rather than a second one of its own.
///
/// Two rules decide what appears:
///
/// * **A leg is drawn only when both of its ends are known.** One end alone
///   would have to be drawn as a point, which on a map is indistinguishable from
///   a place — and a journey half-drawn is a journey misread.
/// * **Nothing connects one place to the next.** The plan says a museum follows
///   a hotel, not that anyone walked between them in a straight line; the legs
///   are what say how the day was travelled. Inventing the connecting line would
///   put journeys on the map that the trip never claimed.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// A place the trip visits, at a position it actually carries.
final class MapPin {
  const MapPin({
    required this.itemId,
    required this.position,
    this.label,
    this.happening = false,
    this.colorValue,
  });

  final int itemId;
  final LatLng position;
  final String? label;

  /// The ARGB color the entry carries, or null to be drawn in the trip's
  /// accent. Named and not pictured, exactly as [MapPath.modeId] is: what a
  /// color *is* belongs to the widget, and this layer stays free of `dart:ui`.
  final int? colorValue;

  /// Whether this entry is under way right now — the map's half of the
  /// timeline's "you are here". Decided by `now_marker.dart`, never here: this
  /// type only carries the answer.
  final bool happening;
}

/// A transport leg, as the line between its two ends.
/// One stored line with the one thing about it the map must know: where it came
/// from. A line somebody walked and a line a router computed are drawn
/// differently, because they claim different things.
final class TrackLine {
  const TrackLine({required this.points, required this.source});

  final List<LatLng> points;
  final TrackSource source;
}

final class MapPath {
  const MapPath({
    required this.itemId,
    required this.segments,
    this.modeId,
    this.label,
    this.happening = false,
    this.dashed = false,
    this.colorValue,
  });

  final int itemId;

  /// The line, split into the pieces that can be drawn without wrapping the
  /// world: normally one, and two for a leg crossing the antimeridian — a
  /// Tokyo-to-Los Angeles flight is one journey but cannot be one polyline, and
  /// drawn as one it would streak backwards across the entire map.
  final List<List<LatLng>> segments;

  /// The row in `TransportModes`, or null when the leg has none. Resolved to an
  /// icon by the widget: what a mode *looks* like is the user's, held in their
  /// own table, so this layer names it and does not picture it.
  final int? modeId;
  final String? label;
  final bool happening;

  /// Drawn broken rather than solid, for a line the router *computed* rather
  /// than one anybody followed. The map can only show a line; whether that line
  /// is a record or a proposal is exactly the difference a reader needs, and a
  /// dash is how every paper map has said it.
  final bool dashed;

  /// The ARGB color the entry carries, or null to be drawn in the trip's
  /// accent. It colors *whichever* line this path turned out to be — the
  /// recorded track when there is one, the segment between the ends when there
  /// is not — since both are the same claim about the same leg.
  final int? colorValue;

  /// Where to hang the mode's icon: half way along the longest segment.
  ///
  /// Measured by **distance**, not by vertex count. Counting vertices put the
  /// icon on the destination of every short leg, because a leg below the
  /// great-circle threshold is two points and the middle of two points is the
  /// second one — so a walk between two platforms wore its icon at the far end
  /// while a long train ride wore it in the middle. It also picks the longer
  /// piece of a split leg by how far it runs rather than by how finely it
  /// happens to be interpolated.
  LatLng get anchor =>
      midpointOf(segments.reduce((a, b) => _length(b) > _length(a) ? b : a));
}

/// A photo, at the position it carries.
///
/// Drawn only when it has one: a picture with no coordinates is not a place, and
/// putting it on the entry it hangs off would be the map claiming to know where
/// it was taken — the entry already has a pin there. Which is the same rule
/// [MapPath] follows for a leg with one end.
///
/// Carries the ids of both possible owners because a photo is reached *through*
/// what it hangs on: an entry's own, or a whole run's shared one.
final class MapPhoto {
  const MapPhoto({
    required this.attachmentId,
    required this.position,
    this.itemId,
    this.groupId,
    this.colorValue,
  });

  final int attachmentId;
  final LatLng position;

  /// The entry this hangs off, or null when it belongs to a run.
  final int? itemId;

  /// The run this hangs off, or null when it belongs to a single entry.
  final int? groupId;

  /// The color of the entry it belongs to, or null for the trip's accent — the
  /// frame is drawn in it, which is what ties the picture to the leg it is
  /// about when several trips' worth of lines are on screen. A run's photo has
  /// none: a group carries no color, and picking one of its members' would be
  /// the accident the group menu exists to avoid. Nor has the trip's own, for
  /// the plainer reason that there is no entry to take one from.
  final int? colorValue;
}

/// Everything a trip contributes to the map.
final class TripMapFeatures {
  const TripMapFeatures({
    required this.pins,
    required this.paths,
    this.photos = const [],
  });

  static const TripMapFeatures empty = TripMapFeatures(pins: [], paths: []);

  final List<MapPin> pins;
  final List<MapPath> paths;
  final List<MapPhoto> photos;

  bool get isEmpty => pins.isEmpty && paths.isEmpty && photos.isEmpty;

  /// Every point drawn, for framing the view. Deliberately includes the
  /// interpolated ones: a great-circle arc bulges well outside the box its two
  /// ends span, and a viewport fitted to the ends alone would cut it off.
  List<LatLng> get allPoints => [
    for (final pin in pins) pin.position,
    for (final path in paths)
      for (final segment in path.segments) ...segment,
    // Photos are framed with the rest: one taken a valley over from everything
    // planned is exactly the thing a viewport fitted to the plan alone would
    // cut off, and it is on the map to be found.
    for (final photo in photos) photo.position,
  ];
}

/// Turns [items] into what the map draws.
///
/// [items] should already be the trip's **live** entries (see `live_items.dart`)
/// in timeline order — the map shows the plan as it stands, exactly as the PDF
/// and the calendar export do, so an option nobody chose never reaches it.
///
/// [happeningItemId] is the entry `now_marker.dart` reports as under way, or
/// null when nothing is.
/// [tracks] are the lines entries were *actually* recorded following, keyed by
/// item id and each already decoded into its points. An entry that has one draws
/// it **instead of** the straight segment between its ends: the chord and the
/// path are two answers to the same question, and drawing both would put a line
/// across the bay beside the line around it. Without one, nothing changes — the
/// great circle between the ends is still the best the plan can say.
///
/// [photos] are the trip's positioned pictures, *unfiltered*: which of them the
/// map may draw is decided here rather than in SQL, because the answer is
/// already in [items] — one belongs on the map when the entry it hangs off is
/// live, or when the run it hangs off still has a live member. Doing it here
/// keeps one definition of "live" for the whole screen instead of a second copy
/// in a query, and a photo on the road not taken is no more drawn than the road
/// is.
TripMapFeatures tripMapFeatures(
  List<ItineraryItem> items, {
  int? happeningItemId,
  Map<int, List<TrackLine>> tracks = const {},
  List<Attachment> photos = const [],
}) {
  final pins = <MapPin>[];
  final paths = <MapPath>[];

  for (final item in items) {
    final happening = item.id == happeningItemId;
    switch (item.kind) {
      case ItemKind.place:
        final position = _point(item.lat, item.lon);
        if (position == null) continue;
        pins.add(
          MapPin(
            itemId: item.id,
            position: position,
            label: item.title ?? item.location,
            happening: happening,
            colorValue: item.colorValue,
          ),
        );
      case ItemKind.transport:
        // A recorded line answers where the leg went; the ends only ever
        // approximated it. Each of its own segments is a separate piece —
        // a recording that stopped and started again leaves a gap that must
        // stay a gap — and each is still split at the antimeridian, since a
        // track may cross it exactly as a flight may.
        final lines = tracks[item.id] ?? const <TrackLine>[];
        // What was actually followed supersedes what a router proposed: once a
        // recording of the leg exists, the computed route adds nothing but a
        // second line beside it. Both stay stored, and the entry's own form
        // lists both — only the map picks.
        final followed = [
          for (final line in lines)
            if (line.source != TrackSource.routed) line,
        ];
        final drawn = followed.isNotEmpty ? followed : lines;
        if (drawn.isNotEmpty) {
          paths.add(
            MapPath(
              itemId: item.id,
              segments: [
                for (final line in drawn) ...splitAtAntimeridian(line.points),
              ],
              modeId: item.mode,
              label: item.title,
              happening: happening,
              dashed: followed.isEmpty,
              colorValue: item.colorValue,
            ),
          );
          continue;
        }
        final from = _point(item.fromLat, item.fromLon);
        final to = _point(item.toLat, item.toLon);
        if (from == null || to == null) continue;
        paths.add(
          MapPath(
            itemId: item.id,
            segments: splitAtAntimeridian(greatCircle(from, to)),
            modeId: item.mode,
            label: item.title,
            happening: happening,
            colorValue: item.colorValue,
          ),
        );
    }
  }

  return TripMapFeatures(
    pins: pins,
    paths: paths,
    photos: _photoMarkers(items, photos),
  );
}

/// The pictures that may be drawn, in the order they were given.
///
/// A photo rides on its owner's liveness and on nothing else — it has its own
/// position, so being drawn is never a question about *where* the entry is, only
/// about whether that entry is part of the plan as it stands. A group's photo
/// needs one live member: a run lies entirely inside one option or entirely
/// outside every one, so any member answers for the whole thing. The trip's own
/// is always drawn, having no part of the plan to be dropped with.
List<MapPhoto> _photoMarkers(
  List<ItineraryItem> items,
  List<Attachment> photos,
) {
  if (photos.isEmpty) return const [];
  final liveItems = {for (final item in items) item.id: item};
  final liveGroups = {
    for (final item in items)
      if (item.groupId != null) item.groupId!,
  };

  final markers = <MapPhoto>[];
  for (final photo in photos) {
    final position = _point(photo.lat, photo.lon);
    if (position == null) continue;
    final owner = photo.itemId == null ? null : liveItems[photo.itemId];
    final onLiveItem = owner != null;
    final onLiveGroup =
        photo.groupId != null && liveGroups.contains(photo.groupId);
    // A picture hung on the **trip** has no liveness question to answer: it
    // belongs to the journey rather than to a part of it, so there is no option
    // it could sit in and nothing that could stop being chosen. It takes the
    // trip's accent, having no entry whose color it could wear.
    final onTrip = photo.itemId == null && photo.groupId == null;
    if (!onLiveItem && !onLiveGroup && !onTrip) continue;
    markers.add(
      MapPhoto(
        attachmentId: photo.id,
        position: position,
        itemId: photo.itemId,
        groupId: photo.groupId,
        colorValue: owner?.colorValue,
      ),
    );
  }
  return markers;
}

LatLng? _point(double? lat, double? lon) =>
    lat == null || lon == null ? null : LatLng(lat, lon);

/// Below this, a straight line and the great circle are within a pixel or two of
/// each other at any usable zoom, so the two ends are the whole line.
const double kGreatCircleThresholdKm = 200;

/// The shortest path over the sphere between [from] and [to], as a list of
/// points starting at [from] and ending at [to].
///
/// Web Mercator is what the map draws in, and a straight line in it is *not* the
/// route anything takes: Hamburg to New York really does pass north of
/// Newfoundland, and drawn as a straight segment it cuts implausibly across the
/// mid-Atlantic. Short hops are returned as the plain two-point line — the
/// difference is invisible and the extra vertices are not free.
List<LatLng> greatCircle(
  LatLng from,
  LatLng to, {
  double thresholdKm = kGreatCircleThresholdKm,
}) {
  final metres = _distance.as(LengthUnit.Meter, from, to);
  if (metres / 1000 <= thresholdKm) return [from, to];

  // One vertex per ~100 km, bounded so a half-world flight stays a manageable
  // polyline and a 300 km hop still bends visibly.
  final steps = (metres / 100000).round().clamp(8, 128);

  final lat1 = _rad(from.latitude);
  final lon1 = _rad(from.longitude);
  final lat2 = _rad(to.latitude);
  final lon2 = _rad(to.longitude);

  // Angular distance between the ends; the interpolation below divides by its
  // sine, which vanishes for coincident (or antipodal) points.
  final d =
      2 *
      math.asin(
        math.sqrt(
          math.pow(math.sin((lat1 - lat2) / 2), 2) +
              math.cos(lat1) *
                  math.cos(lat2) *
                  math.pow(math.sin((lon1 - lon2) / 2), 2),
        ),
      );
  if (d == 0 || d.isNaN) return [from, to];

  final points = <LatLng>[];
  for (var i = 0; i <= steps; i++) {
    final f = i / steps;
    final a = math.sin((1 - f) * d) / math.sin(d);
    final b = math.sin(f * d) / math.sin(d);
    final x =
        a * math.cos(lat1) * math.cos(lon1) +
        b * math.cos(lat2) * math.cos(lon2);
    final y =
        a * math.cos(lat1) * math.sin(lon1) +
        b * math.cos(lat2) * math.sin(lon2);
    final z = a * math.sin(lat1) + b * math.sin(lat2);
    points.add(
      LatLng(
        _deg(math.atan2(z, math.sqrt(x * x + y * y))),
        _deg(math.atan2(y, x)),
      ),
    );
  }
  return points;
}

/// Splits [points] wherever the line crosses the antimeridian, so each piece can
/// be drawn as one polyline.
///
/// A step of more than 180° of longitude is the wrap: the two points are close
/// together on the globe and at opposite edges of the map. Drawn as one line the
/// segment would run the long way round, straight through every other feature on
/// screen. The pieces stop at the edge rather than being stitched across it,
/// which is what a flat map can honestly show.
List<List<LatLng>> splitAtAntimeridian(List<LatLng> points) {
  if (points.length < 2) return [points];
  final segments = <List<LatLng>>[];
  var current = <LatLng>[points.first];
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final point = points[i];
    if ((point.longitude - previous.longitude).abs() > 180) {
      segments.add(current);
      current = <LatLng>[point];
    } else {
      current.add(point);
    }
  }
  segments.add(current);
  return segments;
}

const Distance _distance = Distance(calculator: Haversine());

/// How far [points] runs, end to end, in meters.
double _length(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _distance.as(LengthUnit.Meter, points[i - 1], points[i]);
  }
  return total;
}

/// The point half way along [points], measured by distance.
///
/// Walks the line until half its length is behind, then interpolates inside the
/// segment it lands in — so the answer is a real half-way point rather than
/// whichever vertex happens to sit in the middle of the list. A line whose ends
/// coincide has no half-way point but does have a place, which is that point.
LatLng midpointOf(List<LatLng> points) {
  if (points.length < 2) return points.first;

  final lengths = [
    for (var i = 1; i < points.length; i++)
      _distance.as(LengthUnit.Meter, points[i - 1], points[i]),
  ];
  final total = lengths.fold<double>(0, (a, b) => a + b);
  if (total == 0) return points.first;

  var remaining = total / 2;
  for (var i = 0; i < lengths.length; i++) {
    if (remaining <= lengths[i]) {
      // Interpolated linearly: a segment here is either a short leg drawn as
      // its two ends, or one step of an interpolated arc — in both cases short
      // enough that the straight and the spherical midpoint agree.
      final f = lengths[i] == 0 ? 0.0 : remaining / lengths[i];
      final a = points[i];
      final b = points[i + 1];
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * f,
        a.longitude + (b.longitude - a.longitude) * f,
      );
    }
    remaining -= lengths[i];
  }
  return points.last;
}

double _rad(double degrees) => degrees * math.pi / 180;
double _deg(double radians) => radians * 180 / math.pi;
