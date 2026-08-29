/// Gathering the place marks that would otherwise sit on top of each other.
///
/// The map's half of `photo_clusters.dart`, and the same rule: the gathering is
/// `map_clusters.dart`, measured in screen pixels, so the marks come apart as
/// you zoom in. What differs is what a gathered mark *stands for* — there a
/// picture, here one or more places.
///
/// Places pile up for the reason lines do, on both maps. Across trips: a
/// commute is drawn once per day it was made, so twenty identical pins land on
/// one spot. Within one: a hotel returned to every evening, a station passed
/// through twice, or simply a city's worth of entries at a zoom that shows the
/// country. And where a line under another can still be reached by widening the
/// hitbox, a pin under another cannot be reached at all — a marker wins the hit
/// test against everything beneath it, so the ones underneath are taps nobody
/// can aim.
///
/// Generic in what a place *belongs to*, because the two maps answer different
/// questions with it: the trip map's member is the entry's own [MapPin], the
/// all-trips map's is a [TripPin], which also carries whose entry it is.
library;

import 'dart:math' as math;

import '../../data/database/app_database.dart';
import 'map_clusters.dart';
import 'map_features.dart';

/// How close two pins must be on screen before one hides the other.
///
/// A little wider than the glyph, as the photographs' own radius is, and for
/// the same reason: a pin half behind another is worse than a count.
const double kPinClusterRadius = 30;

/// One mark on the map, standing for one or more places.
final class PinCluster<T> {
  const PinCluster(this.members);

  /// At least one, in the order they were handed over — the order the map
  /// draws in, which is what keeps a mark's face and its list stable while the
  /// camera moves.
  final List<T> members;

  /// The one whose position the mark sits on: the first, and its *own* position
  /// rather than the middle of the group, since this app does not put a mark
  /// where nothing is. The others are within [kPinClusterRadius] of it, so the
  /// difference is a thumb's width.
  T get representative => members.first;

  int get count => members.length;
}

/// Groups [pins] that land within [radius] pixels of each other.
///
/// See [clusterOnScreen] for the rule.
List<PinCluster<T>> clusterPins<T>(
  List<T> pins, {
  required math.Point<double> Function(T) project,
  double radius = kPinClusterRadius,
}) => [
  for (final members in clusterOnScreen(pins, project: project, radius: radius))
    PinCluster(members),
];

/// A place, and the trip it was drawn for.
///
/// The all-trips map's unit is the trip — a [MapPin] alone could not say which
/// accent to draw it in, nor which card a tap should open.
final class TripPin {
  const TripPin({required this.trip, required this.pin});

  final Trip trip;
  final MapPin pin;
}

extension TripPinCluster on PinCluster<TripPin> {
  /// Every trip under this mark, once each, in the order they were given.
  ///
  /// The same fold the line hit test does, and for the same reason: what the
  /// sheet lists is trips, and a stable order is one the user can learn.
  List<Trip> get trips {
    final seen = <int>{};
    return [
      for (final entry in members)
        if (seen.add(entry.trip.id)) entry.trip,
    ];
  }
}
