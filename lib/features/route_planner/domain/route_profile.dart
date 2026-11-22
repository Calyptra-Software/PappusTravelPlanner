import '../../../data/database/tables.dart';

/// How a section of a tour is traveled over the street and path network.
///
/// A profile is a question put to the router ("which way would a mountain bike
/// take"), not a mode of transport: several profiles land on one
/// [TransportMode], which is what the itinerary files the leg under. Hiking is
/// not a profile of its own: the router's only stock foot profile already
/// prefers paths, so [foot] serves a walk through town and a hike alike.
///
/// Stored by [name] where it is stored at all (a leg's route plan), never by
/// index, so the order here is free.
enum RouteProfile {
  foot(TransportMode.walk),

  /// Running: routed as [foot], over the same paths, and filed under walking
  /// as a hike is; only its time is reckoned differently (`runningDuration`).
  run(TransportMode.walk),
  bike(TransportMode.bike),
  roadBike(TransportMode.bike),
  gravelBike(TransportMode.bike),
  mountainBike(TransportMode.bike),
  car(TransportMode.car);

  const RouteProfile(this.transportMode);

  /// The built-in mode a section routed with this profile is filed under. The
  /// row it resolves to is the caller's lookup by `builtinKey`, as for an
  /// imported connection: a built-in the user deleted leaves the leg without a
  /// mode.
  final TransportMode transportMode;

  /// The profile whose way this one takes: running asks the router what
  /// walking does, so a section switched between the two asks nothing again.
  RouteProfile get routedAs => this == run ? foot : this;

  /// Reads back what [name] wrote, or null for a name this version does not
  /// know (a plan written by a newer one).
  static RouteProfile? byName(String? name) {
    for (final profile in values) {
      if (profile.name == name) return profile;
    }
    return null;
  }
}
