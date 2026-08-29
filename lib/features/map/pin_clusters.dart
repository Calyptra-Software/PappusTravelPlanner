/// Gathering the place marks that would otherwise sit on top of each other.
///
/// The all-trips map's half of `photo_clusters.dart`, and the same rule: the
/// gathering is `map_clusters.dart`, measured in screen pixels, so the marks
/// come apart as you zoom in. What differs is what a gathered mark *stands
/// for* — there a picture, here one or more places, each belonging to a trip.
///
/// Places pile up on that map the way lines do, and for the same reason: a
/// commute is drawn once per day it was made, so twenty identical pins land on
/// one spot, and at any zoom showing a country a city's worth of entries is a
/// single blob. Nineteen of those pins can only be taps nobody can aim, since a
/// marker wins the hit test against everything under it.
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

/// A place, and the trip it was drawn for.
///
/// The all-trips map's unit is the trip — a `MapPin` alone could not say which
/// accent to draw it in, nor which card a tap should open.
final class TripPin {
  const TripPin({required this.trip, required this.pin});

  final Trip trip;
  final MapPin pin;
}

/// One mark on the map, standing for one or more places.
final class PinCluster {
  const PinCluster(this.pins);

  /// At least one, in the order they were handed over — which is the
  /// overview's own order of trips, and within a trip its entries' order.
  final List<TripPin> pins;

  /// The one whose position the mark sits on: the first, and its *own*
  /// position rather than the middle of the group, since this app does not put
  /// a mark where nothing is. The others are within [kPinClusterRadius] of it,
  /// so the difference is a thumb's width.
  TripPin get representative => pins.first;

  int get count => pins.length;

  /// The one trip every place here belongs to, or null when they are several.
  ///
  /// What the mark is drawn *in*: a trip's accent is a statement about whose
  /// entry that is, so a mark gathering three trips may not wear one of them —
  /// it would say the other two are that trip's. The count and the tap say the
  /// rest.
  Trip? get onlyTrip {
    final first = representative.trip;
    for (final entry in pins) {
      if (entry.trip.id != first.id) return null;
    }
    return first;
  }

  /// Every trip under this mark, once each, in the order they were given.
  ///
  /// The same fold the line hit test does, and for the same reason: what the
  /// sheet lists is trips, and a stable order is one the user can learn.
  List<Trip> get trips {
    final seen = <int>{};
    return [
      for (final entry in pins)
        if (seen.add(entry.trip.id)) entry.trip,
    ];
  }
}

/// Groups [pins] that land within [radius] pixels of each other.
///
/// See [clusterOnScreen] for the rule; the order handed in is the overview's,
/// so a cluster keeps the same face — and names its trips in the same order —
/// while the map moves.
List<PinCluster> clusterPins(
  List<TripPin> pins, {
  required math.Point<double> Function(TripPin) project,
  double radius = kPinClusterRadius,
}) => [
  for (final members in clusterOnScreen(pins, project: project, radius: radius))
    PinCluster(members),
];
